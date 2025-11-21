SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Stored Procedure: ispPTLOrderAssignSummary                                 */  
/* Creation Date: 21-Feb-2019                                                 */  
/* Copyright: IDS                                                             */  
/* Written by: Shong                                                          */  
/*                                                                            */  
/* Purpose: Assign Batch Number to orders within Load based on passed         */  
/*          parameters value:                                                 */  
/* Called By:                                                                 */  
/*                                                                            */  
/* PVCS Version: 1.0                                                          */  
/*                                                                            */  
/* Version: 1.0                                                               */  
/*                                                                            */  
/* Data Modifications:                                                        */  
/*                                                                            */  
/* Updates:                                                                   */  
/* Date         Author  Rev   Purposes                                        */  
/* 21-02-2019   Chee    1.0   Initial Version                                 */  
/* 24-06-2019   Shong   1.1   Only Show Order# completed Replenishment        */  
/* 01-07-2019   Shong   1.2   Added Reprint Flag                              */  
/* 04-07-2019   Shong   1.3   Added Error Message                             */ 
/* 15-10-2019   Wan01   1.4   Add DPBULK                                      */   
/* 23-09-2019   CSCHONG 1.5   WMS-10493 (CS01)                                */
/******************************************************************************/  
CREATE PROC [dbo].[ispPTLOrderAssignSummary]    
     @c_WaveKey        NVARCHAR(10)   
   , @n_OrderCount     INT  
   , @c_PickZones      NVARCHAR(4000)= ''   
   , @c_BatchSource    NVARCHAR(2)  = 'WP'  --'LP'- Loadkey, 'WP'- Wavekey   
   , @c_Reprint        NVARCHAR(1) = 'N'  
   , @c_loadkeyStart   NVARCHAR(20) = '1'      --(CS01)
   , @c_loadkeyEnd     NVARCHAR(20) = '9999999999'      --(CS01)
   , @b_Debug          INT = 0   
AS    
BEGIN    
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @c_Mode        NVARCHAR(1)  = '0'   
         , @b_Success     INT          = 1       
         , @n_Err         INT          = 0      
         , @c_ErrMsg      NVARCHAR(250)= ''    
         , @c_CallSource  NVARCHAR(10) = ''   
         , @c_UOM         NVARCHAR(500)= ''    
         , @c_ReportErr   NVARCHAR(255)= ''           
  
   DECLARE    
      @n_Continue       INT,    
      @n_StartTCnt      INT, -- Holds the current transaction count     
      @c_OrderKey       NVARCHAR(10),   
      @n_Counter        INT,   
      @n_BatchNo        INT,   
      @n_Count          INT,  
      @c_PickZone       NVARCHAR(10),  
      @b_Found          INT,      
      @c_BatchCode      NVARCHAR(10),   
      @c_OrderMode      NVARCHAR(10),   
      @c_Storerkey      NVARCHAR(15),   
      @c_Facility       NVARCHAR(5),    
      @c_UDF01          NVARCHAR(30),   
      @c_UDF02          NVARCHAR(30),   
      @c_Pickdetailkey  NVARCHAR(10),    
      @c_BatchNo        NVARCHAR(10),       
      @n_RowRef         BIGINT              
   ,  @c_Sourcekey      NVARCHAR(10)               
   ,  @c_ZoneList       NVARCHAR(4000)            
   ,  @c_SQL            NVARCHAR(4000)            
   ,  @c_SQLArgument    NVARCHAR(4000)           
   ,  @n_RecCnt                  INT           
   ,  @c_BatchOrderZoneFromTask  NVARCHAR(30)  
   ,  @c_ExcludeLocType          NVARCHAR(50)  
   ,  @n_Qty                     INT = 0      
   ,  @c_LoadKey                 NVARCHAR(10) = ''  
   ,  @c_LastBatch               VARCHAR(5) = ''  
   ,  @n_wavecounter             INT                   --(CS01)
   ,  @c_wavecount               NVARCHAR(5)           --(CS01)
   ,  @c_trackingno              nvarchar(50)          --(CS01)
   ,  @c_newtrackingno           nvarchar(50)          --(CS01)
   ,  @n_Cntttlpickloc           INT
  
    
  IF GETDATE() < '20190730' -- hardcode date, just in case I forgot.  
  BEGIN  
     INSERT INTO TraceInfo (TraceName, TimeIn, Col1, Col2, Col3, Col4, Col5)  
     VALUES ('ispPTLOrderAssignSummary', GETDATE(), @c_WaveKey, CAST(@n_OrderCount AS VARCHAR(5)), LEFT(@c_PickZones, 20), @c_BatchSource,@c_Reprint)     
  END  
     
  IF @c_BatchSource = 'LP'  
  BEGIN  
      SET @c_LoadKey = @c_WaveKey  
      SET @c_Wavekey = ''  
  END  
  
  SET @c_ZoneList = @c_PickZones               
    
  CREATE TABLE #OrderTable  
   (  rowref    INT NOT NULL IDENTITY(1,1) PRIMARY KEY,  
      Loadkey   NVARCHAR(10),    
      OrderKey  NVARCHAR(10),  
      PickZone  NVARCHAR(10),  
      Score     INT  NULL DEFAULT (0),       -- Fixed to default 0  
      Qty       INT,  
      Diff      INT NULL DEFAULT (0)         -- Fixed to default 0     
     
   )  
     
  Create index IDX_OrderTable_Ord ON #OrderTable (OrderKey, PickZone)  
  
  CREATE TABLE #BatchResultTable  
   (  rowref    INT NOT NULL IDENTITY(1,1) PRIMARY KEY,  
      BatchNo   NVARCHAR(10),  
      OrderKey  NVARCHAR(10),  
      PickZone  NVARCHAR(10),  
      Score     INT NULL DEFAULT (0), --(Wan02) Fixed to default 0  
      Status    NCHAR(1) DEFAULT '0'           
   )  
   Create index IDX_BatchResultTable_Ord ON #BatchResultTable (OrderKey, PickZone)  
  
  CREATE TABLE #PACKTASK (  
     RowRef       INT IDENTITY(1,1)  
    ,WaveKey      NVARCHAR(10)  
    ,Loadkey      NVARCHAR(10)     
    ,Orderkey     NVARCHAR(10)  
    ,TaskBatchNo  NVARCHAR(10)  
    ,PickZone     NVARCHAR(10)  
    ,Qty          INT   
   )  
    
  
  CREATE TABLE #WIP_REPLEN_TASK (  
     RowRef       INT IDENTITY(1,1)  
    ,Orderkey     NVARCHAR(10)  
    ,PickZone     NVARCHAR(10)  
    ,Qty          INT  
	,loadkey      NVARCHAR(10)                        --(CS01)
   )  
    
  INSERT INTO #WIP_REPLEN_TASK (Orderkey, PickZone, Qty,loadkey)         --(CS01)
  SELECT p.OrderKey, L.PickZone, SUM(p.Qty) ,OH.loadkey                  --(CS01) 
  FROM PICKDETAIL AS p WITH(NOLOCK)   
  JOIN LOC AS l WITH(NOLOCK) ON l.Loc = p.Loc   
  JOIN WAVEDETAIL AS w WITH(NOLOCK) ON w.OrderKey = p.OrderKey   
  JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = w.Orderkey                      --(CS01)
  WHERE p.[Status] < '5'  
  AND p.Storerkey='NIKEPH'  
  AND p.UOM IN ('6','7')   
  AND l.LocationType NOT IN ('DYNPICKP', 'DYNPPICK', 'DPBULK') 
  AND p.TaskDetailKey IS NOT NULL   
  AND w.WaveKey = @c_WaveKey   
  AND OH.loadkey >= @c_loadkeyStart                      --(CS01)
  AND OH.loadkey <= @c_loadkeyEnd                        --(CS01)
  GROUP BY p.OrderKey, L.PickZone ,OH.loadkey            --(CS01)  
    
  IF @b_Debug=1  
  BEGIN  
     SELECT * FROM #WIP_REPLEN_TASK   
  END  
    
     
   CREATE TABLE #PickZoneTable   
   (  
      rowref    INT NOT NULL IDENTITY(1,1) PRIMARY KEY,  
      PickZone NVARCHAR(10)  
   )  
  
   CREATE TABLE #OrderAvgScore   
   (  
      rowref    INT NOT NULL IDENTITY(1,1) PRIMARY KEY,  
      OrderKey  NVARCHAR(10),  
      Score     INT NULL DEFAULT (0), --(Wan02) Fixed to default 0  
      )  
     
   Create index IDX_OrderAvgScore_Ord ON #OrderAvgScore  (OrderKey)  
  
   
   CREATE TABLE #TMP_ORDAVGSCORE  
   (  RowRef    INT NOT NULL IDENTITY(1,1) PRIMARY KEY,  
      OrderKey  NVARCHAR(10),  
      AVgScore  INT  
   )  
  
   -- CREATE #TMP_PICKLOC if not calling Function not create it  
   IF OBJECT_ID('tempdb..#TMP_PICKLOC','u') IS NULL   
   BEGIN  
      CREATE TABLE #TMP_PICKLOC  
         (  PickDetailKey  NVARCHAR(10)   NOT NULL DEFAULT ('')   PRIMARY KEY  
         ,  Loc            NVARCHAR(10)   NOT NULL DEFAULT ('')  
         ,  TaskDetailKey  NVARCHAR(10)   NOT NULL DEFAULT ('')  
         )  
      CREATE INDEX #IDX_PICKLOC_LOC ON #TMP_PICKLOC (Loc)  
   END  
   
      
   DECLARE @n_MinScore INT  
   SET @n_MinScore = 0  
  
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0  
   SELECT @c_ErrMsg=''  
   SELECT @b_debug = ISNULL(@b_debug, 0),   
          @b_Found = 0     
  
   IF @@TRANCOUNT = 0  
      BEGIN TRAN  
  
   SET @c_BatchSource = 'LP'                                              
   IF ISNULL(RTRIM(@c_Wavekey),'') <> ''  
   BEGIN         
      SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey  
                  ,@c_Facility = ORDERS.Facility  
      FROM ORDERS (NOLOCK)  
      JOIN wavedetail (NOLOCK) on wavedetail.orderkey = orders.orderkey  
      WHERE wavedetail.wavekey = @c_Wavekey      
  
      SET @c_BatchSource = 'WP'  
   END  
  
   IF ISNULL(RTRIM(@c_Loadkey),'') <> ''                                  
   BEGIN         
      SELECT TOP 1 @c_Storerkey = Storerkey  
                  ,@c_Facility = Facility  
      FROM ORDERS (NOLOCK)  
      WHERE Loadkey = @c_Loadkey  
   END                                                                    
  
   SELECT @c_OrderMode = CASE WHEN @c_Mode = '9' THEN 'S-' + @c_Mode ELSE 'M-' + @c_Mode END  
  
   IF ISNULL(@c_LoadKey, '') = '' AND @c_BatchSource = 'LP'               
   BEGIN  
      SELECT @n_Continue = 3    
      SELECT @n_Err = 63500    
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Loadkey is empty. (ispPTLOrderAssignSummary)'   
      SET @c_ReportErr = 'Loadkey is empty.'               
      GOTO Quit  
   END  
  
   IF ISNULL(RTRIM(@c_Loadkey),'') <> ''                         
   BEGIN  
      IF NOT EXISTS(SELECT 1 FROM LOADPLANDETAIL WITH (NOLOCK) WHERE LoadKey = @c_LoadKey)  
      BEGIN  
         SELECT @n_Continue = 3    
         SELECT @n_Err = 63501   
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid LoadKey. (ispPTLOrderAssignSummary)'  
         SET @c_ReportErr = 'Invalid LoadKey.'   
         GOTO Quit  
      END  
   END                                                                    
  
   IF ISNULL(RTRIM(@c_Wavekey),'') <> ''   
   BEGIN  
      IF NOT EXISTS(SELECT 1 FROM WAVEDETAIL WITH (NOLOCK) WHERE Wavekey = @c_WaveKey)  
      BEGIN  
         SELECT @n_Continue = 3    
         SELECT @n_Err = 63520   
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid WaveKey. (ispPTLOrderAssignSummary)'   
         SET @c_ReportErr = 'Invalid WaveKey.'  
         GOTO Quit  
      END  
   END  
  
   IF ISNULL(@c_UOM,'') <> '' AND @c_Mode <> '9'  
   BEGIN  
      SET @n_Continue = 3    
      SET @n_Err = 63521   
      SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid Mode with UOM. UOM filtering only for Mode = ''9''. (ispPTLOrderAssignSummary)'   
      SET @c_ReportErr = 'Invalid Mode with UOM. UOM filtering only for Mode = 9.'  
      GOTO QUIT   
   END  
  
   IF ISNULL(@n_OrderCount, 0) <= 0  
   BEGIN  
      SELECT @n_Continue = 3    
      SELECT @n_Err = 63502   
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Order count must be larger than zero. (ispPTLOrderAssignSummary)'   
      SET @c_ReportErr = 'Order count must be larger than zero.'  
      GOTO Quit  
   END  
        
   SELECT TOP 1 @c_UDF01 = UDF01, -- maximum Orders limit  
                @c_UDF02 = UDF02  
   FROM CODELKUP(NOLOCK)  
   WHERE Listname = 'BATCHCOUNT'  
   AND Storerkey = @c_Storerkey  
   AND Short = @c_Mode  
   AND (Code2 = @c_Facility OR ISNULL(Code2,'')='')  
   ORDER BY ISNULL(Code2,'') DESC  
     
   IF ISNULL(@c_UDF01,'') <> '' AND ISNUMERIC(@c_UDF01) = 1  
   BEGIN  
        IF ISNULL(@n_OrderCount, 0) > CAST(@c_UDF01 AS INT)  
        BEGIN  
         SELECT @n_Continue = 3    
         SELECT @n_Err = 63503   
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Order count cannot larger than maximum limit ' + RTRIM(@c_UDF01) + ' (ispPTLOrderAssignSummary)'   
         SET @c_ReportErr = 'Order count cannot larger than maximum limit.'  
         GOTO Quit  
        END  
   END  
  
   IF ISNULL(@c_UDF02,'') <> '' AND NOT EXISTS (SELECT 1 FROM dbo.fnc_DelimSplit(',', @c_UDF02) AS VAL WHERE ISNUMERIC(Colvalue) = 0)   
   BEGIN  
      IF NOT EXISTS(SELECT 1 FROM dbo.fnc_DelimSplit(',', @c_UDF02) AS VAL   
                     WHERE CAST(colvalue AS INT) = @n_Ordercount)   
      BEGIN  
         SELECT @n_Continue = 3    
         SELECT @n_Err = 63504   
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Order count value must be in ' + RTRIM(@c_UDF02) + ' (ispPTLOrderAssignSummary)'   
         SET @c_ReportErr = 'Order count value must be in ' + RTRIM(@c_UDF02)  
         GOTO Quit  
      END  
   END
   
   IF @b_Debug= 1
	BEGIN
	  Select '@c_BatchOrderZoneFromTask'
	END   
   
   SET @c_BatchOrderZoneFromTask = ''  
   EXEC nspGetRight    
        @c_Facility  = @c_Facility     
      , @c_StorerKey = @c_StorerKey    
      , @c_sku       = NULL   
      , @c_ConfigKey = 'BatchOrderZoneFromTask'   
      , @b_Success   = @b_Success         OUTPUT    
      , @c_authority = @c_BatchOrderZoneFromTask   OUTPUT      
      , @n_err       = @n_err             OUTPUT      
      , @c_errmsg    = @c_errmsg          OUTPUT    
      , @c_Option1   = @c_ExcludeLocType  OUTPUT  

	  SET @c_trackingno = ''        --CS01
  
   IF ISNULL(@c_Reprint,'') NOT IN ('Y','N') AND ISNUMERIC(ISNULL(@c_Reprint,'')) = 0  
      SET @c_Reprint = 'N'  

	IF @b_Debug= 1
	BEGIN
	  Select @c_Reprint '@c_Reprint'
	END  
  
   IF @c_Reprint = 'Y' OR ISNUMERIC(@c_Reprint) = 1  
   BEGIN  
   IF ISNUMERIC(@c_Reprint) = 1  
       SET @c_LastBatch = @c_Reprint  
    ELSE  
    BEGIN  
       SELECT @c_LastBatch = MAX(PrintFlag)
	         ,@c_trackingno = MAX(Trackingno)   
       FROM   ORDERS AS O WITH (NOLOCK)   
       JOIN WAVEDETAIL AS WO WITH(NOLOCK) ON WO.OrderKey = O.OrderKey   
       WHERE WO.WaveKey = @c_WaveKey  
	   AND O.loadkey >= @c_loadkeyStart                      --(CS01)
       AND O.loadkey <= @c_loadkeyEnd                        --(CS01) 
       AND O.PrintFlag BETWEEN '1' AND '9999'  
	   
	IF @b_Debug= 1
	BEGIN
	  Select @c_Reprint '@c_Reprint', @c_trackingno '@c_trackingno'
	END 
	     
    END       
   END  
   ELSE   
   BEGIN  
    SET @c_LastBatch = '0'  
    
	SET @c_trackingno = ''           --(CS01)
	SET @c_newtrackingno = ''        --(CS01)
	  
    SELECT TOP 1 @c_LastBatch = PrintFlag  
    FROM   ORDERS AS O WITH (NOLOCK)   
    JOIN WAVEDETAIL AS WO WITH(NOLOCK) ON WO.OrderKey = O.OrderKey   
    WHERE WO.WaveKey = @c_WaveKey  
    AND O.loadkey >= @c_loadkeyStart                      --(CS01)
    AND O.loadkey <= @c_loadkeyEnd                        --(CS01) 
    AND O.PrintFlag BETWEEN '1' AND '9999'  
    ORDER BY O.PrintFlag DESC  

	--CS01 START
    SELECT @c_trackingno = MAX(O.Trackingno)
	FROM   ORDERS AS O WITH (NOLOCK)   
    JOIN WAVEDETAIL AS WO WITH(NOLOCK) ON WO.OrderKey = O.OrderKey   
    WHERE WO.WaveKey = @c_WaveKey  
    AND O.loadkey >= @c_loadkeyStart                      --(CS01)
    AND O.loadkey <= @c_loadkeyEnd                        --(CS01) 
	  
    IF @c_LastBatch = '0'  
       SET @c_LastBatch = '1'  
    ELSE   
     SET @c_LastBatch = CAST( @c_LastBatch AS INT) + 1        
   END  

  IF @b_Debug= 1
	BEGIN
	  Select 'TrackingNo ' , @c_trackingno '@c_trackingno'
	END 
    
	IF ISNULL(@c_trackingno,'') <> ''
	BEGIN
	  
	  SET @c_wavecount = ''
	  SET @n_wavecounter = 0

	  SET @c_wavecount = RIGHT(@c_trackingno,3)
	  IF @c_wavecount <> '999'
	  BEGIN
	    SET @n_wavecounter = CAST(@c_wavecount as int) + 1
      END
	  ELSE
	  BEGIN
	    SET @n_wavecounter = 1
	  END
	  SET @c_newtrackingno  = @c_WaveKey + '-' + RIGHT('000' + CAST(@n_wavecounter as nvarchar(3)),3)

	END
	ELSE
	BEGIN
	   SET @n_wavecounter = 1
	   SET @c_newtrackingno = @c_WaveKey + '-' + RIGHT('000' + CAST(@n_wavecounter as nvarchar(3)),3)
	END
    --CS01 END

	IF @b_Debug= 1
	BEGIN
	  Select 'Get TrackingNo ' , @c_newtrackingno '@c_newtrackingno'
	END
     
   SET @c_SQL= N'SELECT DISTINCT'       
             + ' PD.PickDetailKey'  
             + CASE WHEN @c_BatchOrderZoneFromTask = '1'   
                    THEN ',Loc = ISNULL(TD.LogicalToLoc,PD.Loc)'  
                    ELSE ',Loc = PD.Loc'  
                    END  
             + CASE WHEN @c_BatchOrderZoneFromTask = '1'   
                    THEN ',TaskDetailKey=ISNULL(TD.TaskDetailKey,'''')'  
                    ELSE ',TaskDetailKey='''''  
                    END               
             + ' FROM ORDERS O WITH (NOLOCK)'  
             + ' JOIN PICKDETAIL PD WITH (NOLOCK) ON O.Orderkey = PD.Orderkey'  
             + CASE WHEN @c_BatchOrderZoneFromTask = '1'   
                    THEN ' LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey'  
                    ELSE ''  
                    END  
             + CASE WHEN @c_BatchSource = 'LP'   
                    THEN ' WHERE O.Loadkey = @c_Loadkey'   
                    ELSE ' WHERE EXISTS(SELECT 1 FROM dbo.WAVEDETAIL WD (NOLOCK) WHERE WD.Orderkey = O.Orderkey ' +  
                         ' AND WD.WAVEKey = @c_Wavekey) '  
                    END  
             + CASE WHEN @c_UOM = '' THEN ''  
                    ELSE ' AND EXISTS(SELECT 1 FROM dbo.fnc_DelimSplit('','',@c_UOM) WHERE ColValue = PD.UOM)'  
                    END   
             + CASE WHEN @c_Reprint = 'N' THEN ' AND O.PrintFlag IN (''N'',''Y'') '   
                    ELSE ' AND O.PrintFlag = ''' +  @c_LastBatch + ''' '  
                    END   
             --+ CASE WHEN @c_BatchOrderZoneFromTask = '1'   
             --       THEN ' AND PD.Orderkey NOT IN (SELECT PID.Orderkey FROM PICKDETAIL PID (NOLOCK) WHERE ISNULL(TaskDetailKey,'''') = '''' AND PID.OrderKey = O.OrderKey) '  
             --       ELSE ''  
             --       END
             + ' AND O.Status <> ''9'' '  
			 + ' AND O.loadkey >= @c_loadkeyStart  '                    --(CS01)
             + ' AND O.loadkey <= @c_loadkeyEnd  '                      --(CS01)

               
   SET @c_SQLArgument = N'@c_Loadkey         NVARCHAR(10)'  
                      + ',@c_Wavekey         NVARCHAR(10)'  
                      + ',@c_UOM             NVARCHAR(500)'  
					  + ',@c_loadkeyStart    NVARCHAR(500)'             --(CS01)
					  + ',@c_loadkeyEnd      NVARCHAR(500)'             --(CS01)
  
   IF @b_debug = 1  
   BEGIN  
      PRINT '-- Insert TMP_PICKLOC'  
      PRINT @c_SQL  
   END  
     
   INSERT INTO #TMP_PICKLOC  
      (  PickDetailKey    
      ,  Loc   
      ,  TaskDetailKey)  
        
   EXEC sp_executesql @c_SQL  
         ,  @c_SQLArgument  
         ,  @c_Loadkey  
         ,  @c_Wavekey   
         ,  @c_UOM  
		 ,  @c_loadkeyStart
		 ,  @c_loadkeyEnd
  
   IF @c_BatchOrderZoneFromTask = '1'  
   BEGIN  
      IF NOT EXISTS (SELECT 1 FROM #TMP_PICKLOC)  
      BEGIN  
         SET @n_Continue = 3    
         SET @n_Err = 63522     
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Pick To Loc not found. (ispPTLOrderAssignSummary)'  
         SET @c_ReportErr = 'Pick To Loc not found.'   
         GOTO QUIT  
      END  
  
      SET @n_RecCnt = 0  
      SET @c_SQL= N'SELECT @n_RecCnt = COUNT(1)'       
             + ' FROM #TMP_PICKLOC PL'  
             + ' JOIN LOC L WITH (NOLOCK) ON (PL.Loc = L.Loc)'  
             + ' WHERE PL.TaskDetailKey = '''''  
             + ' AND L.LocationType NOT IN (''DYNPPICK'', ''DYNPICKP'', ''DPBULK'') '  
  
      SET @c_SQLArgument = N'@c_ExcludeLocType  NVARCHAR(50)'  
                         + ',@n_RecCnt          INT OUTPUT'   
  
      EXEC sp_executesql @c_SQL  
                     ,  @c_SQLArgument  
                     ,  @c_ExcludeLocType  
                     ,  @n_RecCnt OUTPUT 


      /*CS01 START*/
	  SET @n_Cntttlpickloc = 0
	  SET @c_SQL= N'SELECT @n_Cntttlpickloc = COUNT(1)'       
             + ' FROM #TMP_PICKLOC PL'  
  
      SET @c_SQLArgument = N'@c_ExcludeLocType  NVARCHAR(50)'  
                         + ',@n_Cntttlpickloc          INT OUTPUT'   
  
      EXEC sp_executesql @c_SQL  
                     ,  @c_SQLArgument  
                     ,  @c_ExcludeLocType  
                     ,  @n_Cntttlpickloc OUTPUT 

	  /*CS01 END*/	
					 
	  IF @b_Debug=1  
      BEGIN  
      PRINT ' --- @c_ExcludeLocType: ' + @c_ExcludeLocType  
         PRINT @c_SQL  
         SELECT '#TMP_PICKLOC', * FROM #TMP_PICKLOC 
		 SELECT @n_RecCnt '@n_RecCnt' ,@n_Cntttlpickloc '@n_Cntttlpickloc' 
      END
  
      IF @n_RecCnt > 0 AND (@n_RecCnt = @n_Cntttlpickloc)          --CS01
      BEGIN  
         SET @n_Continue = 3    
         SET @n_Err = 63523    
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Pick Task Not Yet Released. (ispPTLOrderAssignSummary)'   
         SET @c_ReportErr = 'Pick Task Not Yet Released.'  
         GOTO QUIT   
      END        
  
                         
   END  
     
   IF @c_PickZones = 'ALL'   
   BEGIN  
      SET @c_ZoneList = ''  
      SELECT @c_ZoneList = @c_ZoneList + RTRIM(Loc.PickZone) + ','  
      FROM #TMP_PICKLOC PL             
      JOIN LOC WITH (NOLOCK) ON  PL.Loc = LOC.Loc  
      GROUP BY LOC.PickZone  
      ORDER BY LOC.PickZone  
        
      IF ISNULL(@c_ZoneList,'') <> ''  
      BEGIN  
         SET @c_ZoneList = LEFT(@c_ZoneList, LEN(RTRIM(@c_ZoneList)) - 1)  
         SET @c_PickZones = @c_ZoneList  
      END  
      ELSE  
      BEGIN   
         SET @c_ZoneList = @c_PickZones     
      END  
   END    
  
   WHILE CHARINDEX(',', @c_PickZones) > 0  
   BEGIN  
      SET @n_Count = CHARINDEX(',', @c_PickZones)    
      INSERT INTO #PickZoneTable ( PickZone ) VALUES (LTRIM(RTRIM(SUBSTRING(@c_PickZones, 1, @n_Count-1))))  
      SET @c_PickZones = SUBSTRING(@c_PickZones, @n_Count+1, LEN(@c_PickZones)-@n_Count)  
   END   
     
   INSERT INTO #PickZoneTable (PickZone) VALUES (LTRIM(RTRIM(@c_PickZones)))  
  
   WHILE @@TRANCOUNT > 0   
      COMMIT TRAN;     
  
   IF @@TRANCOUNT = 0  
      BEGIN TRAN;   
    
   IF ISNULL(RTRIM(@c_Wavekey),'') <> ''  
   BEGIN  
      INSERT INTO #TMP_ORDAVGSCORE (OrderKey, AVgScore)  
      SELECT OS.OrderKey, AVG(OS.Score) AS AVgScore       
      FROM (   
              SELECT PD.Orderkey, L.Loc, ISNULL(L.Score,1) AS Score   
              FROM PickDetail PD (NOLOCK)  
              JOIN WAVEDETAIL WPD (NOLOCK) ON (WPD.OrderKey = PD.OrderKey)  
              JOIN #TMP_PICKLOC PL  ON (PD.PickDetailKey = PL.PickDetailkey)           
              JOIN LOC          L  (NOLOCK) ON (PL.Loc = L.Loc)                        
     WHERE WPD.WaveKey = @c_WaveKey  
     GROUP BY PD.OrderKey, L.LOC, L.Score  
         ) AS OS  
      GROUP BY OS.Orderkey  
   END  
   ELSE  
   BEGIN  
      INSERT INTO #TMP_ORDAVGSCORE (OrderKey, AVgScore)  
      SELECT OS.OrderKey, AVG(OS.Score) AS AVgScore       
      FROM (   
              SELECT PD.Orderkey, L.Loc, ISNULL(L.Score,1) AS Score   
              FROM PickDetail PD (NOLOCK)  
              JOIN LOADPLANDETAIL LPD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)  
              JOIN #TMP_PICKLOC PL          ON (PD.PickDetailKey = PL.PickDetailkey)   
              JOIN LOC          L  (NOLOCK) ON (PL.Loc = L.Loc)                        
              WHERE LPD.LoadKey = @c_LoadKey  
              GROUP BY PD.OrderKey, L.LOC, Score   
           ) AS OS  
      GROUP BY OS.Orderkey  
   END  
    
   IF @b_Debug = 1
   BEGIN
     SELECT '#PickZoneTable',* FROM #PickZoneTable
   END
   -- Assign batch based on pickzone given  
   DECLARE C_PICKZONE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT PickZone FROM #PickZoneTable  
  
  
   OPEN C_PICKZONE  
   FETCH NEXT FROM C_PICKZONE INTO @c_PickZone  
  
   WHILE (@@FETCH_STATUS <> -1)            
   BEGIN   
      IF @b_Debug=1  
      BEGIN  
         PRINT '>>> Process Zone: ' + @c_PickZone   
      END        
        
      INSERT INTO #OrderTable (Loadkey, OrderKey, PickZone, Score, Qty)  
      SELECT OH.Loadkey, PD.OrderKey, @c_PickZone As PickZone,   
               0 AS Score,   
               SUM(PD.Qty) AS Qty  
      FROM PickDetail PD (NOLOCK)   
      JOIN #TMP_PICKLOC PL ON (PD.PickDetailKey = PL.PickDetailkey)          
      JOIN LOC L  (NOLOCK) ON (PL.Loc = L.Loc)   
      JOIN ORDERS OH (NOLOCK) ON (PD.Orderkey = OH.Orderkey)                       
      WHERE L.PickZone = @c_PickZone  
      AND NOT EXISTS( SELECT 1 FROM #WIP_REPLEN_TASK PT (NOLOCK)   
                      WHERE PD.Orderkey = PT.Orderkey )         --(CS01)
      AND NOT EXISTS( SELECT 1 FROM #PACKTASK PT (NOLOCK)   
                      WHERE PD.Orderkey = PT.Orderkey   
                      AND PT.PickZone = @c_PickZone)                        
      AND PD.UOM NOT IN ('2') -- Exclude to PACKStation  
      GROUP BY OH.Loadkey, PD.OrderKey  
      ORDER BY MIN(L.LogicalLocation), MIN(L.Loc)  
   
      SELECT @n_Count = COUNT(1)   
      FROM #OrderTable  
  
      IF @b_Debug=1  
      BEGIN  
	     PRINT '@c_PickZone: ' + @c_PickZone 
         PRINT '>>> @n_OrderCount: ' + CAST(@n_OrderCount AS VARCHAR)   
         PRINT '    @n_Count: ' + CAST(@n_Count AS VARCHAR)  
           
         SELECT * FROM #OrderTable  
      END        
  
      IF @n_Count > 0  
      BEGIN  
     
         SET @c_BatchCode = ''  
         SET @n_Counter = 0   
                 
         EXECUTE nspg_getkey  
            'ORDBATCHNO'  
            , 9  
            , @c_BatchCode   OUTPUT  
            , @b_Success OUTPUT  
            , @n_Err     OUTPUT  
            , @c_ErrMsg  OUTPUT  
  
         SET @c_BatchCode = 'B' + @c_BatchCode  
  
         DECLARE CUR_ORDERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT rowref, Loadkey, OrderKey, Qty   
         FROM #OrderTable   
         WHERE PickZone = @c_PickZone   
         ORDER BY Score, Loadkey, OrderKey   
           
         OPEN CUR_ORDERS  
         FETCH NEXT FROM CUR_ORDERS INTO @n_RowRef, @c_Loadkey, @c_OrderKey, @n_Qty    
         WHILE @@FETCH_STATUS = 0   
         BEGIN  
            IF @b_Debug=1  
            BEGIN  
               PRINT '>>> OrderKey: ' + @c_OrderKey   
            END     
                    
            INSERT INTO #PACKTASK  
            (  
               WaveKey,  
               Loadkey,  
               Orderkey,  
               TaskBatchNo,  
               PickZone,  
               Qty  
            )  
            VALUES  
            (  
               @c_WaveKey,  
               @c_Loadkey,  
               @c_OrderKey,  
               @c_BatchCode,  
               @c_PickZone,  
               @n_Qty  
            )  

	IF @b_Debug= 1
	BEGIN
	  Select 'Update TrackingNo ' , @c_newtrackingno '@c_newtrackingno',@c_OrderKey '@c_OrderKey'
	END
              
            UPDATE ORDERS WITH (ROWLOCK)  
               SET PrintFlag = @c_LastBatch,  
			       Trackingno = CASE WHEN ISNULL(Trackingno,'') = '' THEN @c_newtrackingno ELSE Trackingno END,          --(CS01) 
                   TrafficCop = NULL,   
                   EditDate = GETDATE(),   
                   EditWho = SUSER_SNAME()   
            WHERE OrderKey = @c_OrderKey  
              
            SET @n_Counter = @n_Counter + 1  
			--CS01 START

	IF ISNULL(@c_newtrackingno,'') <> ''
	BEGIN
	  
	  SET @c_wavecount = ''
	  SET @n_wavecounter = 0

	  SET @c_wavecount = RIGHT(@c_newtrackingno,3)
	  IF @c_wavecount <> '999'
	  BEGIN
	    SET @n_wavecounter = CAST(@c_wavecount as int) + 1
      END
	  ELSE
	  BEGIN
	    SET @n_wavecounter = 1
	  END
	  SET @c_newtrackingno  = @c_WaveKey + '-' + RIGHT('000' + CAST(@n_wavecounter as nvarchar(3)),3)

	END
	ELSE
	BEGIN
	   SET @n_wavecounter = 1
	   SET @c_newtrackingno = @c_WaveKey + '-' + RIGHT('000' + CAST(@n_wavecounter as nvarchar(3)),3)
	END

			--CS01 END
            IF @n_Counter >= @n_OrderCount  
            BEGIN  
               EXECUTE nspg_getkey  
                  'ORDBATCHNO'  
                  , 9  
                  , @c_BatchCode OUTPUT  
                  , @b_Success   OUTPUT  
                  , @n_Err       OUTPUT  
                  , @c_ErrMsg    OUTPUT  
  
               SET @c_BatchCode = 'B' + @c_BatchCode                
                 
               DELETE FROM #OrderTable  
               WHERE rowref = @n_RowRef  
                 
               SET @n_Counter = 0   
            END  
            FETCH NEXT FROM CUR_ORDERS INTO @n_RowRef, @c_Loadkey, @c_OrderKey, @n_Qty    
         END    
         CLOSE CUR_ORDERS   
         DEALLOCATE CUR_ORDERS   
      END -- IF @n_Counter > 0  
                  
      WHILE @@TRANCOUNT > 0   
         COMMIT TRAN;                                 
  
      FETCH NEXT FROM C_PICKZONE INTO @c_PickZone  
   END    
   CLOSE C_PICKZONE            
   DEALLOCATE C_PICKZONE 
   
    IF @b_Debug=1  
      BEGIN  
         SELECT '#PACKTASK',* FROM #PACKTASK  
      END   
  
  
Quit:  
   IF @n_Continue=3 AND @c_ReportErr <> ''  
   BEGIN  
    SELECT @c_WaveKey,   
           '' AS [Orderkey],   
           '' AS [TaskBatchNo],   
           @c_PickZones AS [PickZone],   
           0 AS Qty,   
           GETDATE() AS DeliveryDate,   
           @c_ReportErr,  
             '' AS [Loadkey]  
           ,'' as TrackingNo              --(CS01)
   END  
   ELSE   
   BEGIN  
      SELECT PT.WaveKey, PT.Orderkey, PT.TaskBatchNo, PT.PickZone, PT.Qty, OH.DeliveryDate, '' AS [ReportErr], PT.Loadkey ,OH.Trackingno as TrackingNo 
      FROM #PACKTASK PT        JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = PT.Orderkey  
      ORDER BY TaskBatchNo, RowRef      
   END  
  
   SET @c_PickZones = @c_ZoneList  -- RETURN ZoneList to PickZone  
   WHILE @@TRANCOUNT < @n_StartTCnt  
      BEGIN TRAN;    
           
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_Success = 0    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
      ELSE    
      BEGIN    
         WHILE @@TRANCOUNT > @n_StartTCnt    
         BEGIN    
            COMMIT TRAN    
         END    
      END    
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPTLOrderAssignSummary'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN    
   END    
   ELSE    
   BEGIN    
      SELECT @b_Success = 1    
      WHILE @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         COMMIT TRAN    
      END    
      RETURN    
   END    
  
END -- Procedure  

GO