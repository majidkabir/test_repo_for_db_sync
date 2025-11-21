SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/            
/* Stored Proc : isp_GetDBSize                                             */            
/* Creation Date:  25th Aug 2009                                           */            
/* Copyright: IDS                                                          */            
/* Written by: SHONG                                                       */            
/*                                                                         */            
/* Purpose: Volumetrics                                                    */            
/*                                                                         */            
/*                                                                         */            
/* Usage:                                                                  */            
/*                                                                         */            
/* PVCS Version: 1.0                                                       */            
/*                                                                         */            
/* Version: 5.4                                                            */            
/*                                                                         */            
/* Data Modifications:                                                     */            
/*                                                                         */            
/* Updates:                                                                */            
/* Date        Author      Ver   Purposes                                  */            
/* 2015-10-28  KHLim       1.1   change temp table to table variable (KH01)*/
/* 2019-01-22  KHLim       1.2   force select mdf instead of ndf row (KH02)*/
/* 2021-04-30  KSChin      1.3   Replace XP_CMDSHELL by call GetDiskInfo   */
/***************************************************************************/            

CREATE PROC [dbo].[isp_GetDBSize]  
AS  
BEGIN   
SET NOCOUNT ON

   declare @id int   -- The object id that takes up space  
   ,@type character(2) -- The object type.  
  ,@pages bigint   -- Working variable for size calc.  
  ,@dbname sysname  
  ,@dbsize bigint  
  ,@logsize bigint  
  ,@reservedpages  bigint  
  ,@usedpages  bigint  
  ,@rowCount bigint  
  ,@db_filename NVARCHAR(60)  
  ,@log_filename NVARCHAR(60) 

Declare @totalDiskMB  bigint,
        @freeMB       bigint,
        @dletter      NVARCHAR(1)
  
-- Start Get total disk size and free size 
DECLARE	@Drive TINYINT,
	@SQL NVARCHAR(100)

SET	@Drive = 97

-- Setup Staging Area
/* Comment by KSChin to remove usage of XP_CMDSHELL
   DECLARE	@Drives TABLE
	(
		Drive NVARCHAR(1),
		Info NVARCHAR(80)
	)

WHILE @Drive <= 122
	BEGIN
		SET	@SQL = 'EXEC XP_CMDSHELL ''fsutil volume diskfree ' + master.dbo.fnc_GetCharASCII(@Drive) + ':'''
		
		INSERT	@Drives
			(
				Info
			)
		EXEC	(@SQL)

		UPDATE	@Drives
		SET	Drive = master.dbo.fnc_GetCharASCII(@Drive)
		WHERE	Drive IS NULL

		SET	@Drive = @Drive + 1
	END

-- Show the expected output
--KH01 start
DECLARE	@dspace TABLE
	(
		Drive       NVARCHAR(1),
      TotalMB     NVARCHAR(100),
      FreeMB      NVARCHAR(100),
      AvailFreeMB NVARCHAR(100)
	)

INSERT INTO @dspace
	(
		Drive       ,
      TotalMB     ,
      FreeMB      ,
      AvailFreeMB 
	)
SELECT		Drive,
		SUM(CASE WHEN Info LIKE 'Total # of bytes             : %' THEN CAST(REPLACE(SUBSTRING(Info, 32, 48), master.dbo.fnc_GetCharASCII(13), '') AS BIGINT) ELSE CAST(0 AS BIGINT) END)/ 1024/ 1024 AS TotalMB,
		SUM(CASE WHEN Info LIKE 'Total # of free bytes        : %' THEN CAST(REPLACE(SUBSTRING(Info, 32, 48), master.dbo.fnc_GetCharASCII(13), '') AS BIGINT) ELSE CAST(0 AS BIGINT) END)/ 1024/ 1024 AS FreeMB,
		SUM(CASE WHEN Info LIKE 'Total # of avail free bytes  : %' THEN CAST(REPLACE(SUBSTRING(Info, 32, 48), master.dbo.fnc_GetCharASCII(13), '') AS BIGINT) ELSE CAST(0 AS BIGINT) END)/ 1024/ 1024 AS AvailFreeMB
--INTO #dspace    --KH01
FROM		(
			SELECT	Drive,
				Info
			FROM	@Drives
			WHERE	Info LIKE 'Total # of %'
		) AS d
GROUP BY	Drive
ORDER BY	Drive
-- End Get total disk size and free size 
--KH01 end*/

--Added by KSChin to call the sp_Getdiskinfo to get the diskspace usage
CREATE TABLE #TEM (DRIVE NVARCHAR(5) NULL, DRIVENAME NVARCHAR(20) NULL, DRIVESIZEMB BIGINT, DRIVEFREESPACEMB BIGINT)
INSERT #TEM (DRIVE, DRIVENAME,DRIVESIZEMB,DRIVEFREESPACEMB)
EXEC master.dbo.sp_Getdiskinfo

SELECT LEFT(DRIVE,1)  AS Drive, DRIVESIZEMB AS TotalMB, DRIVEFREESPACEMB  AS FreeMB
INTO #dspace FROM #TEM ORDER BY DRIVE
  
 select @dbsize  = (convert(bigint,case when status & 64 = 0 then size else 0 end))  
     ,@db_filename = [filename]
 from dbo.sysfiles  
 Where  status & 64 = 0  
 and filename like '%mdf' -- KH02

 select @logsize = (convert(bigint,case when status & 64 <> 0 then size else 0 end))  
     ,@log_filename = [filename]
 from dbo.sysfiles  
 where status & 64 <> 0  
  
 select @reservedpages = sum(a.total_pages),  
  @usedpages = sum(a.used_pages),  
  @pages = sum(  
    CASE  
     -- XML-Index and FT-Index-Docid is not considered "data", but is part of "index_size"  
     When it.internal_type IN (202,204) Then 0  
     When a.type <> 1 Then a.used_pages  
     When p.index_id < 2 Then a.data_pages  
     Else 0  
    END  
   )  
 from sys.partitions p join sys.allocation_units a on p.partition_id = a.container_id  
  left join sys.internal_tables it on p.object_id = it.object_id  
  
-- disk space for DB file

Select @totalDiskMB = TotalMB,
      @freeMB = FreeMB,
      @dletter = Drive
FROM #dspace   --update by KSCHIN to #dspace
where Drive = left(@db_filename, 1)




 /* unallocated space could not be negative */  
 select   
  database_name = db_name(),  
  database_size = ltrim(str((convert (dec (15,2),@dbsize) -- + convert (dec (15,2),@logsize)
                  ) * 8192 / 1048576,15,2) + ' MB'),  
  'unallocated space' = ltrim(str((case when @dbsize >= @reservedpages   
                                          then (convert (dec (15,2),@dbsize) - convert (dec (15,2),@reservedpages)) * 8192 / 1048576   
                                          else 0   
                                     end),15,2) + ' MB')  ,
  Drive_letter =  @dletter,
  Disk_Size = str(@totalDiskMB) + ' MB',
  Disk_Availfree_Size = str(@freeMB) + ' MB'

END -- Procedure

EXEC isp_GETdbsize

GO