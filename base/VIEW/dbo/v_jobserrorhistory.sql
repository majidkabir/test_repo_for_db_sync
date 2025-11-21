SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

Create View [dbo].[V_JobsErrorHistory]
AS
SELECT name=cast(a.name as NVARCHAR(35)),
step_name,
status=case run_status when 0 then 'FAILED' when 3 then 'CANCELED' end,
StartDateTime = ( CONVERT 
    ( 
        DATETIME, 
        RTRIM(run_date) 
    ) 
    +  
    ( 
        run_time * 9 
        + run_time % 10000 * 6 
        + run_time % 100 * 10 
    ) / 216e4 ),
b.message
FROM msdb.dbo.sysjobs as a (NOLOCK) JOIN msdb.dbo.sysjobhistory as b (NOLOCK)
ON a.job_id=b.job_id
WHERE run_status in ('0','3') and left(a.name, 3) in ( 'DMT', 'MNT', 'ARC')   -- Error Job


GO