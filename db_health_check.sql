-- ============================================================================
-- Oracle Database Health Check - HTML Report
-- Usage: @db_health_check.sql
-- Output: db_health_report_<DBNAME>_<TIMESTAMP>.html
-- Supports: RAC, Data Guard, CDB/PDB
-- No Diagnostics Pack required (V$ views only)
-- ============================================================================

-- ============================================================================
-- CONFIGURATION - Adjust thresholds here
-- ============================================================================
DEFINE tbs_warn_pct       = 85
DEFINE tbs_crit_pct       = 95
DEFINE ash_minutes        = 15
DEFINE rman_days          = 7
DEFINE longops_min_secs   = 60
DEFINE top_n              = 10

-- ============================================================================
-- SETUP
-- ============================================================================
SET TERMOUT OFF
SET ECHO OFF
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF
SET MARKUP HTML OFF
SET PAGESIZE 0
SET LINESIZE 2000
SET LONG 100000
SET LONGCHUNKSIZE 100000
SET TRIMSPOOL ON
SET TRIMOUT ON

COLUMN db_unique NEW_VALUE v_db_unique NOPRINT
COLUMN spool_ts  NEW_VALUE v_spool_ts  NOPRINT
SELECT db_unique_name db_unique FROM v$database;
SELECT TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS') spool_ts FROM dual;

SPOOL db_health_report_&v_db_unique._&v_spool_ts..html

-- ============================================================================
-- HTML HEADER & CSS
-- ============================================================================
PROMPT <!DOCTYPE html>
PROMPT <html lang="en">
PROMPT <head>
PROMPT <meta charset="UTF-8">
PROMPT <title>Oracle DB Health Check</title>
PROMPT <style>
PROMPT   * { margin: 0; padding: 0; box-sizing: border-box; }
PROMPT   body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f0f2f5; color: #333; padding: 20px; }
PROMPT   .header { background: linear-gradient(135deg, #1a1a2e, #16213e); color: #fff; padding: 30px; border-radius: 10px; margin-bottom: 20px; }
PROMPT   .header h1 { font-size: 24px; margin-bottom: 5px; }
PROMPT   .header p { font-size: 13px; opacity: 0.8; }
PROMPT   .section { background: #fff; border-radius: 8px; margin-bottom: 16px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); overflow: hidden; }
PROMPT   .section-title { background: #16213e; color: #fff; padding: 12px 20px; font-size: 15px; font-weight: 600; }
PROMPT   .section-title span.num { background: rgba(255,255,255,0.2); padding: 2px 8px; border-radius: 10px; margin-right: 8px; font-size: 12px; }
PROMPT   .section-body { padding: 15px 20px; overflow-x: auto; }
PROMPT   table { width: 100%; border-collapse: collapse; font-size: 13px; }
PROMPT   th { background: #e8eaf0; color: #16213e; padding: 8px 12px; text-align: left; font-weight: 600; white-space: nowrap; border-bottom: 2px solid #d0d3da; }
PROMPT   td { padding: 7px 12px; border-bottom: 1px solid #eee; white-space: nowrap; }
PROMPT   tr:hover td { background: #f8f9fc; }
PROMPT   .badge { display: inline-block; padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; }
PROMPT   .badge-green { background: #d4edda; color: #155724; }
PROMPT   .badge-yellow { background: #fff3cd; color: #856404; }
PROMPT   .badge-red { background: #f8d7da; color: #721c24; }
PROMPT   .badge-blue { background: #d1ecf1; color: #0c5460; }
PROMPT   .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px; }
PROMPT   .summary-card { background: #f8f9fc; border-radius: 6px; padding: 15px; border-left: 4px solid #16213e; }
PROMPT   .summary-card .label { font-size: 11px; color: #888; text-transform: uppercase; letter-spacing: 0.5px; }
PROMPT   .summary-card .value { font-size: 20px; font-weight: 700; color: #16213e; margin-top: 4px; }
PROMPT   .no-data { color: #999; font-style: italic; padding: 10px 0; }
PROMPT   .footer { text-align: center; color: #999; font-size: 12px; margin-top: 20px; padding: 15px; }
PROMPT </style>
PROMPT </head>
PROMPT <body>

-- ============================================================================
-- SECTION 0: HEADER
-- ============================================================================
SET HEADING OFF PAGESIZE 0 FEEDBACK OFF

PROMPT <div class="header">
PROMPT <h1>Oracle Database Health Check Report</h1>

SELECT '<p>Database: <strong>' || d.name || '</strong> | '
    || 'Unique Name: <strong>' || d.db_unique_name || '</strong> | '
    || 'Generated: <strong>' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') || '</strong></p>'
FROM v$database d;

PROMPT </div>

-- ============================================================================
-- SECTION 1: DATABASE OVERVIEW
-- ============================================================================
PROMPT <div class="section">
PROMPT <div class="section-title"><span class="num">1</span>Database Overview</div>
PROMPT <div class="section-body">
PROMPT <div class="summary-grid">

SELECT '<div class="summary-card"><div class="label">Database Name</div><div class="value">'
    || d.name || '</div></div>'
    || '<div class="summary-card"><div class="label">DB Unique Name</div><div class="value">'
    || d.db_unique_name || '</div></div>'
    || '<div class="summary-card"><div class="label">Database Role</div><div class="value">'
    || d.database_role || '</div></div>'
    || '<div class="summary-card"><div class="label">Open Mode</div><div class="value">'
    || d.open_mode || '</div></div>'
    || '<div class="summary-card"><div class="label">Log Mode</div><div class="value">'
    || d.log_mode || '</div></div>'
    || '<div class="summary-card"><div class="label">Platform</div><div class="value">'
    || d.platform_name || '</div></div>'
FROM v$database d;

SELECT '<div class="summary-card"><div class="label">Version</div><div class="value">'
    || i.version || '</div></div>'
    || '<div class="summary-card"><div class="label">Instance (' || i.instance_name || ')</div><div class="value">'
    || i.status || '</div></div>'
    || '<div class="summary-card"><div class="label">Host</div><div class="value">'
    || i.host_name || '</div></div>'
    || '<div class="summary-card"><div class="label">Uptime</div><div class="value">'
    || TRUNC(SYSDATE - i.startup_time) || 'd '
    || TRUNC(MOD((SYSDATE - i.startup_time)*24, 24)) || 'h '
    || TRUNC(MOD((SYSDATE - i.startup_time)*1440, 60)) || 'm</div></div>'
FROM v$instance i;

SELECT '<div class="summary-card"><div class="label">RAC Instances</div><div class="value">'
    || COUNT(*) || '</div></div>'
FROM gv$instance;

SELECT '<div class="summary-card"><div class="label">OS Load (Cluster)</div><div class="value">'
    || ROUND(SUM(os.value), 2) || '</div></div>'
FROM gv$osstat os
WHERE os.stat_name = 'LOAD';

PROMPT </div></div></div>

-- ============================================================================
-- SECTION 2: RAC INSTANCE STATUS
-- ============================================================================
PROMPT <div class="section">
PROMPT <div class="section-title"><span class="num">2</span>RAC Instance Status</div>
PROMPT <div class="section-body">
PROMPT <table>
PROMPT <tr><th>Inst#</th><th>Instance Name</th><th>Host</th><th>Status</th><th>Version</th><th>Startup Time</th><th>Uptime</th><th>OS Load</th></tr>

SELECT '<tr>'
    || '<td>' || i.inst_id || '</td>'
    || '<td>' || i.instance_name || '</td>'
    || '<td>' || i.host_name || '</td>'
    || '<td><span class="badge '
    || CASE WHEN i.status = 'OPEN' THEN 'badge-green' ELSE 'badge-red' END
    || '">' || i.status || '</span></td>'
    || '<td>' || i.version || '</td>'
    || '<td>' || TO_CHAR(i.startup_time, 'YYYY-MM-DD HH24:MI') || '</td>'
    || '<td>' || TRUNC(SYSDATE - i.startup_time) || 'd '
    || TRUNC(MOD((SYSDATE - i.startup_time)*24, 24)) || 'h</td>'
    || '<td>' || ROUND(os.value, 2) || '</td>'
    || '</tr>'
FROM gv$instance i
JOIN gv$osstat os ON os.inst_id = i.inst_id AND os.stat_name = 'LOAD'
ORDER BY i.inst_id;

PROMPT </table>
PROMPT </div></div>

-- ============================================================================
-- SECTION 3: SYSTEM METRICS (Per Instance)
-- ============================================================================
PROMPT <div class="section">
PROMPT <div class="section-title"><span class="num">3</span>System Metrics (Current)</div>
PROMPT <div class="section-body">
PROMPT <table>
PROMPT <tr><th>Metric</th><th>Unit</th><th>Inst 1</th><th>Inst 2</th><th>Inst 3</th><th>Inst 4</th><th>Total</th></tr>

SELECT '<tr>'
    || '<td><strong>' || metric_name || '</strong></td>'
    || '<td>' || metric_unit || '</td>'
    || '<td>' || NVL(TO_CHAR(ROUND(MAX(CASE WHEN inst_id=1 THEN value END),2)), '-') || '</td>'
    || '<td>' || NVL(TO_CHAR(ROUND(MAX(CASE WHEN inst_id=2 THEN value END),2)), '-') || '</td>'
    || '<td>' || NVL(TO_CHAR(ROUND(MAX(CASE WHEN inst_id=3 THEN value END),2)), '-') || '</td>'
    || '<td>' || NVL(TO_CHAR(ROUND(MAX(CASE WHEN inst_id=4 THEN value END),2)), '-') || '</td>'
    || '<td><strong>'
    || ROUND(SUM(CASE WHEN metric_name LIKE '%CPU%' OR metric_name LIKE '%Latency%' THEN value/COUNT(*) OVER (PARTITION BY metric_name) ELSE value END), 2)
    || '</strong></td>'
    || '</tr>'
FROM gv$sysmetric
WHERE group_id = 2
  AND metric_name IN (
    'Host CPU Utilization (%)',
    'Current OS Load',
    'Average Active Sessions',
    'CPU Usage Per Sec',
    'Physical Read Total IO Requests Per Sec',
    'Physical Write Total IO Requests Per Sec',
    'I/O Megabytes per Second',
    'Logical Reads Per Sec',
    'DB Block Changes Per Sec',
    'User Transaction Per Sec',
    'Redo Generated Per Sec',
    'Network Traffic Volume Per Sec',
    'Logons Per Sec',
    'Average Synchronous Single-Block Read Latency'
  )
GROUP BY metric_name, metric_unit
ORDER BY metric_name;

PROMPT </table>
PROMPT </div></div>

-- ============================================================================
-- SECTION 4: ACTIVE SESSIONS (Top 10)
-- ============================================================================
PROMPT <div class="section">
PROMPT <div class="section-title"><span class="num">4</span>Top Active Sessions</div>
PROMPT <div class="section-body">
PROMPT <table>
PROMPT <tr><th>Inst</th><th>SID,Serial#</th><th>Username</th><th>Status</th><th>Wait Event</th><th>Wait(s)</th><th>SQL ID</th><th>Module</th><th>Machine</th><th>Logon Time</th></tr>

SELECT * FROM (
  SELECT '<tr>'
    || '<td>' || s.inst_id || '</td>'
    || '<td>' || s.sid || ',' || s.serial# || '</td>'
    || '<td>' || NVL(s.username, 'SYS') || '</td>'
    || '<td><span class="badge '
    || CASE WHEN s.status = 'ACTIVE' THEN 'badge-green' ELSE 'badge-blue' END
    || '">' || s.status || '</span></td>'
    || '<td>' || NVL(s.event, 'ON CPU') || '</td>'
    || '<td>' || NVL(TO_CHAR(ROUND(s.wait_time_micro/1000000,1)), '0') || '</td>'
    || '<td>' || NVL(s.sql_id, '-') || '</td>'
    || '<td>' || NVL(SUBSTR(s.module, 1, 30), '-') || '</td>'
    || '<td>' || NVL(SUBSTR(s.machine, 1, 25), '-') || '</td>'
    || '<td>' || TO_CHAR(s.logon_time, 'MM/DD HH24:MI') || '</td>'
    || '</tr>' AS row_html
  FROM gv$session s
  WHERE s.type = 'USER'
    AND s.status = 'ACTIVE'
    AND s.username IS NOT NULL
  ORDER BY s.wait_time_micro DESC
)
WHERE ROWNUM <= &top_n;

PROMPT </table>
PROMPT </div></div>

-- ============================================================================
-- SECTION 5: TOP WAIT EVENTS (Current)
-- ============================================================================
PROMPT <div class="section">
PROMPT <div class="section-title"><span class="num">5</span>Top Wait Events (Current)</div>
PROMPT <div class="section-body">
PROMPT <table>
PROMPT <tr><th>Event</th><th>Wait Class</th><th>Waits/Sec</th><th>Avg Wait(ms)</th><th>Time Waited(s)</th></tr>

SELECT * FROM (
  SELECT '<tr>'
    || '<td>' || e.event || '</td>'
    || '<td><span class="badge '
    || CASE e.wait_class
         WHEN 'User I/O' THEN 'badge-blue'
         WHEN 'Concurrency' THEN 'badge-yellow'
         WHEN 'Administrative' THEN 'badge-red'
         ELSE 'badge-green'
       END
    || '">' || e.wait_class || '</span></td>'
    || '<td>' || ROUND(SUM(e.wait_count), 1) || '</td>'
    || '<td>' || ROUND(CASE WHEN SUM(e.wait_count) > 0 THEN SUM(e.time_waited) / SUM(e.wait_count) ELSE 0 END, 2) || '</td>'
    || '<td>' || ROUND(SUM(e.time_waited)/100, 2) || '</td>'
    || '</tr>' AS row_html
  FROM gv$eventmetric e
  WHERE e.wait_class != 'Idle'
    AND e.wait_count > 0
  GROUP BY e.event, e.wait_class
  ORDER BY SUM(e.time_waited) DESC
)
WHERE ROWNUM <= &top_n;

PROMPT </table>
PROMPT </div></div>

-- ============================================================================
-- SECTION 6: TOP SQL BY RESOURCES
-- ============================================================================
PROMPT <div class="section">
PROMPT <div class="section-title"><span class="num">6</span>Top SQL by Elapsed Time (Current Cursors)</div>
PROMPT <div class="section-body">
PROMPT <table>
PROMPT <tr><th>#</th><th>SQL ID</th><th>Elapsed(s)</th><th>CPU(s)</th><th>Executions</th><th>Rows</th><th>Buffer Gets</th><th>Disk Reads</th><th>Module</th><th>SQL Text (first 80 chars)</th></tr>

SELECT * FROM (
  SELECT '<tr>'
    || '<td>' || ROWNUM || '</td>'
    || '<td>' || sql_id || '</td>'
    || '<td>' || ROUND(elapsed_time/1000000, 2) || '</td>'
    || '<td>' || ROUND(cpu_time/1000000, 2) || '</td>'
    || '<td>' || executions || '</td>'
    || '<td>' || rows_processed || '</td>'
    || '<td>' || buffer_gets || '</td>'
    || '<td>' || disk_reads || '</td>'
    || '<td>' || NVL(SUBSTR(module, 1, 20), '-') || '</td>'
    || '<td>' || REPLACE(REPLACE(SUBSTR(sql_text, 1, 80), '<', '&lt;'), '>', '&gt;') || '</td>'
    || '</tr>' AS row_html
  FROM (
    SELECT sql_id, elapsed_time, cpu_time, executions, rows_processed,
           buffer_gets, disk_reads, module, sql_text
    FROM gv$sql
    WHERE executions > 0
    ORDER BY elapsed_time DESC
  )
  WHERE ROWNUM <= 10
);

PROMPT </table>
PROMPT </div></div>

-- ============================================================================
-- SECTION 7: BLOCKING SESSIONS
-- ============================================================================
PROMPT <div class="section">
PROMPT <div class="section-title"><span class="num">7</span>Blocking Sessions</div>
PROMPT <div class="section-body">

SELECT CASE WHEN COUNT(*) = 0
         THEN '<p class="no-data">No blocking sessions detected.</p>'
         ELSE '<table>'
           || '<tr><th>Blocker Inst</th><th>Blocker SID</th><th>Wait Event</th><th>SQL ID</th><th>Object</th><th># Blocked</th><th>Max Wait(s)</th></tr>'
       END
FROM gv$session
WHERE final_blocking_session_status = 'VALID';

SELECT '<tr>'
    || '<td>' || final_blocking_instance || '</td>'
    || '<td>' || final_blocking_session || '</td>'
    || '<td>' || event || '</td>'
    || '<td>' || NVL(sql_id, '-') || '</td>'
    || '<td>' || row_wait_obj# || '</td>'
    || '<td>' || COUNT(*) || '</td>'
    || '<td>' || ROUND(MAX(wait_time_micro)/1000000, 2) || '</td>'
    || '</tr>'
FROM gv$session
WHERE final_blocking_session_status = 'VALID'
GROUP BY final_blocking_instance, final_blocking_session, event, sql_id, row_wait_obj#
ORDER BY COUNT(*) DESC;

SELECT CASE WHEN COUNT(*) > 0 THEN '</table>' ELSE '' END
FROM gv$session
WHERE final_blocking_session_status = 'VALID';

PROMPT </div></div>

-- ============================================================================
-- SECTION 8: TABLESPACE USAGE
-- ============================================================================
PROMPT <div class="section">
PROMPT <div class="section-title"><span class="num">8</span>Tablespace Usage</div>
PROMPT <div class="section-body">
PROMPT <table>
PROMPT <tr><th>Tablespace</th><th>Allocated (MB)</th><th>Used (MB)</th><th>Free (MB)</th><th>Used %</th><th>Status</th></tr>

SELECT '<tr>'
    || '<td>' || tablespace_name || '</td>'
    || '<td>' || TO_CHAR(ROUND(alloc_mb, 1), '999,999.0') || '</td>'
    || '<td>' || TO_CHAR(ROUND(used_mb, 1), '999,999.0') || '</td>'
    || '<td>' || TO_CHAR(ROUND(alloc_mb - used_mb, 1), '999,999.0') || '</td>'
    || '<td>' || ROUND(pct_used, 1) || '%</td>'
    || '<td><span class="badge '
    || CASE
         WHEN pct_used >= &tbs_crit_pct THEN 'badge-red">CRITICAL'
         WHEN pct_used >= &tbs_warn_pct THEN 'badge-yellow">WARNING'
         ELSE 'badge-green">OK'
       END
    || '</span></td>'
    || '</tr>'
FROM (
  SELECT f.tablespace_name,
         ROUND(f.total_bytes / 1048576, 1) alloc_mb,
         ROUND(NVL(u.used_bytes, 0) / 1048576, 1) used_mb,
         CASE WHEN f.total_bytes > 0
              THEN ROUND((NVL(u.used_bytes,0) / f.total_bytes) * 100, 1)
              ELSE 0
         END pct_used
  FROM (SELECT tablespace_name, SUM(bytes) total_bytes
        FROM dba_data_files
        GROUP BY tablespace_name) f
  LEFT JOIN (SELECT tablespace_name, SUM(bytes) used_bytes
             FROM dba_segments
             GROUP BY tablespace_name) u
    ON f.tablespace_name = u.tablespace_name
  ORDER BY pct_used DESC
);

PROMPT </table>
PROMPT </div></div>

-- ============================================================================
-- SECTION 9: ASH SUMMARY (Last 15 min)
-- ============================================================================
PROMPT <div class="section">
PROMPT <div class="section-title"><span class="num">9</span>ASH Top Events &amp; SQL (Last &ash_minutes min)</div>
PROMPT <div class="section-body">
PROMPT <table>
PROMPT <tr><th>Event</th><th>SQL ID</th><th>Wait Samples</th><th>% of Total</th><th>Session State</th></tr>

SELECT * FROM (
  SELECT '<tr>'
    || '<td>' || NVL(event, 'ON CPU') || '</td>'
    || '<td>' || NVL(sql_id, '-') || '</td>'
    || '<td>' || cnt || '</td>'
    || '<td>' || ROUND(100 * RATIO_TO_REPORT(cnt) OVER (), 1) || '%</td>'
    || '<td><span class="badge '
    || CASE session_state WHEN 'ON CPU' THEN 'badge-green' ELSE 'badge-yellow' END
    || '">' || session_state || '</span></td>'
    || '</tr>' AS row_html
  FROM (
    SELECT NVL(event, 'ON CPU') event,
           sql_id,
           session_state,
           COUNT(*) cnt
    FROM gv$active_session_history
    WHERE sample_time >= SYSDATE - &ash_minutes/1440
      AND session_type = 'FOREGROUND'
    GROUP BY event, sql_id, session_state
    ORDER BY COUNT(*) DESC
  )
  WHERE ROWNUM <= &top_n
);

PROMPT </table>
PROMPT </div></div>

-- ============================================================================
-- SECTION 10: DATA GUARD STATUS
-- ============================================================================
PROMPT <div class="section">
PROMPT <div class="section-title"><span class="num">10</span>Data Guard Status</div>
PROMPT <div class="section-body">

SELECT CASE WHEN COUNT(*) = 0
         THEN '<p class="no-data">Data Guard not configured or no stats available.</p>'
         ELSE '<table>'
           || '<tr><th>Metric</th><th>Value</th><th>Unit</th><th>Computed At</th><th>Status</th></tr>'
       END
FROM v$dataguard_stats;

SELECT '<tr>'
    || '<td><strong>' || name || '</strong></td>'
    || '<td>' || NVL(value, 'N/A') || '</td>'
    || '<td>' || NVL(unit, '-') || '</td>'
    || '<td>' || NVL(TO_CHAR(time_computed, 'YYYY-MM-DD HH24:MI:SS'), '-') || '</td>'
    || '<td><span class="badge '
    || CASE
         WHEN name LIKE '%lag%' AND value IS NOT NULL AND value != '+00 00:00:00' THEN 'badge-yellow">LAG DETECTED'
         WHEN value IS NULL THEN 'badge-red">NO DATA'
         ELSE 'badge-green">OK'
       END
    || '</span></td>'
    || '</tr>'
FROM v$dataguard_stats;

SELECT CASE WHEN COUNT(*) > 0 THEN '</table>' ELSE '' END
FROM v$dataguard_stats;

PROMPT <br>
PROMPT <strong>Archive Destination Status:</strong>

SELECT CASE WHEN COUNT(*) = 0
         THEN '<p class="no-data">No archive destinations configured.</p>'
         ELSE '<table>'
           || '<tr><th>Dest#</th><th>Destination</th><th>Status</th><th>Target</th><th>Schedule</th><th>Error</th></tr>'
       END
FROM v$archive_dest
WHERE status != 'INACTIVE'
  AND target != 'NONE';

SELECT '<tr>'
    || '<td>' || dest_id || '</td>'
    || '<td>' || NVL(SUBSTR(destination, 1, 40), '-') || '</td>'
    || '<td><span class="badge '
    || CASE status WHEN 'VALID' THEN 'badge-green' ELSE 'badge-red' END
    || '">' || status || '</span></td>'
    || '<td>' || target || '</td>'
    || '<td>' || schedule || '</td>'
    || '<td>' || NVL(SUBSTR(error, 1, 50), '-') || '</td>'
    || '</tr>'
FROM v$archive_dest
WHERE status != 'INACTIVE'
  AND target != 'NONE'
ORDER BY dest_id;

SELECT CASE WHEN COUNT(*) > 0 THEN '</table>' ELSE '' END
FROM v$archive_dest
WHERE status != 'INACTIVE'
  AND target != 'NONE';

PROMPT </div></div>

-- ============================================================================
-- SECTION 11: RMAN BACKUP STATUS
-- ============================================================================
PROMPT <div class="section">
PROMPT <div class="section-title"><span class="num">11</span>RMAN Backup Status (Last &rman_days Days)</div>
PROMPT <div class="section-body">

SELECT CASE WHEN COUNT(*) = 0
         THEN '<p class="no-data">No RMAN backups found in the last &rman_days days.</p>'
         ELSE '<table>'
           || '<tr><th>Start Time</th><th>End Time</th><th>Type</th><th>Status</th><th>Size (MB)</th><th>Duration</th><th>Day</th></tr>'
       END
FROM v$rman_backup_job_details
WHERE start_time > SYSDATE - &rman_days;

SELECT '<tr>'
    || '<td>' || TO_CHAR(j.start_time, 'YYYY-MM-DD HH24:MI') || '</td>'
    || '<td>' || TO_CHAR(j.end_time, 'YYYY-MM-DD HH24:MI') || '</td>'
    || '<td>' || j.input_type || '</td>'
    || '<td><span class="badge '
    || CASE j.status
         WHEN 'COMPLETED' THEN 'badge-green">COMPLETED'
         WHEN 'RUNNING' THEN 'badge-blue">RUNNING'
         WHEN 'FAILED' THEN 'badge-red">FAILED'
         ELSE 'badge-yellow">' || j.status
       END
    || '</span></td>'
    || '<td>' || TO_CHAR(ROUND(j.output_bytes/1048576, 1), '999,999.0') || '</td>'
    || '<td>' || j.time_taken_display || '</td>'
    || '<td>' || DECODE(TO_CHAR(j.start_time, 'D'),
         1,'Sun', 2,'Mon', 3,'Tue', 4,'Wed', 5,'Thu', 6,'Fri', 7,'Sat') || '</td>'
    || '</tr>'
FROM v$rman_backup_job_details j
WHERE j.start_time > SYSDATE - &rman_days
ORDER BY j.start_time DESC;

SELECT CASE WHEN COUNT(*) > 0 THEN '</table>' ELSE '' END
FROM v$rman_backup_job_details
WHERE start_time > SYSDATE - &rman_days;

PROMPT </div></div>

-- ============================================================================
-- SECTION 12: LONG RUNNING OPERATIONS
-- ============================================================================
PROMPT <div class="section">
PROMPT <div class="section-title"><span class="num">12</span>Long Running Operations</div>
PROMPT <div class="section-body">

SELECT CASE WHEN COUNT(*) = 0
         THEN '<p class="no-data">No long-running operations detected (threshold: &longops_min_secs s).</p>'
         ELSE '<table>'
           || '<tr><th>Inst</th><th>SID,Serial#</th><th>Username</th><th>SQL ID</th><th>Operation</th><th>Elapsed(s)</th><th>Remaining(s)</th><th>% Done</th><th>Message</th></tr>'
       END
FROM gv$session_longops
WHERE time_remaining > 0
  AND elapsed_seconds > &longops_min_secs;

SELECT '<tr>'
    || '<td>' || inst_id || '</td>'
    || '<td>' || sid || ',' || serial# || '</td>'
    || '<td>' || NVL(username, 'SYS') || '</td>'
    || '<td>' || NVL(sql_id, '-') || '</td>'
    || '<td>' || sql_plan_operation || ' ' || NVL(sql_plan_options, '') || '</td>'
    || '<td>' || elapsed_seconds || '</td>'
    || '<td>' || time_remaining || '</td>'
    || '<td>'
    || CASE WHEN totalwork > 0 THEN TO_CHAR(ROUND(sofar/totalwork*100, 1)) || '%' ELSE '-' END
    || '</td>'
    || '<td>' || SUBSTR(message, 1, 60) || '</td>'
    || '</tr>'
FROM gv$session_longops
WHERE time_remaining > 0
  AND elapsed_seconds > &longops_min_secs
ORDER BY elapsed_seconds DESC;

SELECT CASE WHEN COUNT(*) > 0 THEN '</table>' ELSE '' END
FROM gv$session_longops
WHERE time_remaining > 0
  AND elapsed_seconds > &longops_min_secs;

PROMPT </div></div>

-- ============================================================================
-- SECTION 13: ALERT LOG ERRORS (Last 24h)
-- ============================================================================
PROMPT <div class="section">
PROMPT <div class="section-title"><span class="num">13</span>Recent Alert Log Errors (Last 24h)</div>
PROMPT <div class="section-body">

SELECT CASE WHEN COUNT(*) = 0
         THEN '<p class="no-data">No ORA- errors in the alert log in the last 24 hours.</p>'
         ELSE '<table>'
           || '<tr><th>Timestamp</th><th>Instance</th><th>Message</th></tr>'
       END
FROM gv$diag_alert_ext
WHERE originating_timestamp > SYSTIMESTAMP - INTERVAL '1' DAY
  AND message_text LIKE '%ORA-%'
  AND ROWNUM <= 1;

SELECT * FROM (
  SELECT '<tr>'
    || '<td>' || TO_CHAR(originating_timestamp, 'YYYY-MM-DD HH24:MI:SS') || '</td>'
    || '<td>' || inst_id || '</td>'
    || '<td>' || REPLACE(REPLACE(SUBSTR(message_text, 1, 120), '<', '&lt;'), '>', '&gt;') || '</td>'
    || '</tr>' AS row_html
  FROM gv$diag_alert_ext
  WHERE originating_timestamp > SYSTIMESTAMP - INTERVAL '1' DAY
    AND message_text LIKE '%ORA-%'
  ORDER BY originating_timestamp DESC
)
WHERE ROWNUM <= 20;

SELECT CASE WHEN COUNT(*) > 0 THEN '</table>' ELSE '' END
FROM gv$diag_alert_ext
WHERE originating_timestamp > SYSTIMESTAMP - INTERVAL '1' DAY
  AND message_text LIKE '%ORA-%'
  AND ROWNUM <= 1;

PROMPT </div></div>

-- ============================================================================
-- FOOTER
-- ============================================================================
PROMPT <div class="footer">

SELECT 'Generated on ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS')
    || ' | Database: ' || d.name
    || ' | Oracle DBA Toolkit Health Check v1.0'
FROM v$database d;

PROMPT </div>
PROMPT </body>
PROMPT </html>

SPOOL OFF
SET TERMOUT ON
SET HEADING ON
SET FEEDBACK ON
SET VERIFY ON
SET PAGESIZE 14
SET LINESIZE 80
SET MARKUP HTML OFF

PROMPT
PROMPT ============================================
PROMPT  Health check report generated successfully!
PROMPT  File: db_health_report_&v_db_unique._&v_spool_ts..html
PROMPT ============================================
PROMPT
