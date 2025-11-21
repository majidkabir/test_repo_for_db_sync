SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: ispLPPK12                                               */
/* Creation Date: 2023-04-2O                                            */
/* Copyright: MAERSK                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-22379 TH-Royal Canin Cartonization                      */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 20-APR-2023 NJOW     1.0   DEVOPS Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[ispLPPK12]
   @cLoadKey    NVARCHAR(10),  
   @bSuccess    INT      OUTPUT,
   @nErr        INT      OUTPUT, 
   @cErrMsg     NVARCHAR(250) OUTPUT
AS                                    
BEGIN                                 
   SET NOCOUNT ON                     
   SET ANSI_NULLS OFF                 
   SET QUOTED_IDENTIFIER OFF          
   SET CONCAT_NULL_YIELDS_NULL OFF    
                                      
   DECLARE @c_SourceType              NVARCHAR(30)
          ,@b_debug                   INT = 0
          ,@n_StartTCnt               INT          = 0
          ,@n_Continue                INT          = 1
          ,@c_CartonGroup             NVARCHAR(10) = ''
          ,@c_Storerkey               NVARCHAR(15) 
          ,@c_Facility                NVARCHAR(5)
          ,@c_RLWAV_Opt5              NVARCHAR(4000)
          ,@c_NewCarton               NVARCHAR(1)
          ,@n_CartonNo                INT
          ,@c_CartonType              NVARCHAR(10)
          ,@c_CurrCartonType          NVARCHAR(10)
          ,@n_CartonMaxCube           DECIMAL(16,9)
          ,@n_CartonMaxWeight         DECIMAL(16,9)           
          ,@n_CartonMaxCount          INT
          ,@n_CartonMaxSku            INT
          ,@c_Orderkey                NVARCHAR(10)
          ,@n_OrderCube               DECIMAL(16,9)
          ,@n_OrderWeight             DECIMAL(16,9)                         
          ,@n_RowID                   INT
          ,@n_OrderQty                INT
          ,@c_Sku                     NVARCHAR(20)
          ,@n_StdCube                 DECIMAL(16,9)
          ,@n_StdGrossWgt             DECIMAL(16,9)
          ,@n_QtyCanPackByCube        INT
          ,@n_QtyCanPackByWgt         INT
          ,@n_QtyCanPackByCount       INT
          ,@n_QtyCanPack              INT
          ,@c_PickslipNo              NVARCHAR(10)
          ,@c_LabelNo                 NVARCHAR(20)
          ,@n_TotCartonCube           DECIMAL(16,9)
          ,@n_TotCartonWeight         DECIMAL(16,9)
          ,@n_TotCartonQty            INT
          ,@n_PackQty                 INT      
          ,@n_PickdetQty              INT
          ,@c_PickDetailKey           NVARCHAR(10)
          ,@c_NewPickDetailKey        NVARCHAR(10)
          ,@n_SplitQty                INT
          ,@c_CartonItemOptimize      NVARCHAR(30) = 'Y'
          ,@c_SkuBUSR7                NVARCHAR(30)
          ,@n_CaseCnt                 INT
          ,@n_Innerpack               INT
          ,@c_KeyName                 NVARCHAR(18)
             
   SELECT @n_StartTCnt = @@TRANCOUNT, @n_Continue = 1, @bSuccess = 1, @nerr = 0, @cerrmsg = '', @c_SourceType = 'ispLPPK12'
   
   IF @@TRANCOUNT = 0
      BEGIN TRAN

   --Create pickdetail Work in progress temporary table    
   IF @n_continue IN(1,2)
   BEGIN
      CREATE TABLE #PickDetail_WIP(
         [PickDetailKey] [nvarchar](18) NOT NULL PRIMARY KEY,
         [CaseID] [nvarchar](20) NOT NULL DEFAULT (' '),
         [PickHeaderKey] [nvarchar](18) NOT NULL,
         [OrderKey] [nvarchar](10) NOT NULL,
         [OrderLineNumber] [nvarchar](5) NOT NULL,
         [Lot] [nvarchar](10) NOT NULL,
         [Storerkey] [nvarchar](15) NOT NULL,
         [Sku] [nvarchar](20) NOT NULL,
         [AltSku] [nvarchar](20) NOT NULL DEFAULT (' '),
         [UOM] [nvarchar](10) NOT NULL DEFAULT (' '),
         [UOMQty] [int] NOT NULL DEFAULT ((0)),
         [Qty] [int] NOT NULL DEFAULT ((0)),
         [QtyMoved] [int] NOT NULL DEFAULT ((0)),
         [Status] [nvarchar](10) NOT NULL DEFAULT ('0'),
         [DropID] [nvarchar](20) NOT NULL DEFAULT (''),
         [Loc] [nvarchar](10) NOT NULL DEFAULT ('UNKNOWN'),
         [ID] [nvarchar](18) NOT NULL DEFAULT (' '),
         [PackKey] [nvarchar](10) NULL DEFAULT (' '),
         [UpdateSource] [nvarchar](10) NULL DEFAULT ('0'),
         [CartonGroup] [nvarchar](10) NULL,
         [CartonType] [nvarchar](10) NULL,
         [ToLoc] [nvarchar](10) NULL  DEFAULT (' '),
         [DoReplenish] [nvarchar](1) NULL DEFAULT ('N'),
         [ReplenishZone] [nvarchar](10) NULL DEFAULT (' '),
         [DoCartonize] [nvarchar](1) NULL DEFAULT ('N'),
         [PickMethod] [nvarchar](1) NOT NULL DEFAULT (' '),
         [WaveKey] [nvarchar](10) NOT NULL DEFAULT (' '),
         [EffectiveDate] [datetime] NOT NULL DEFAULT (getdate()),
         [AddDate] [datetime] NOT NULL DEFAULT (getdate()),
         [AddWho] [nvarchar](128) NOT NULL DEFAULT (suser_sname()),
         [EditDate] [datetime] NOT NULL DEFAULT (getdate()),
         [EditWho] [nvarchar](128) NOT NULL DEFAULT (suser_sname()),
         [TrafficCop] [nvarchar](1) NULL,
         [ArchiveCop] [nvarchar](1) NULL,
         [OptimizeCop] [nvarchar](1) NULL,
         [ShipFlag] [nvarchar](1) NULL DEFAULT ('0'),
         [PickSlipNo] [nvarchar](10) NULL,
         [TaskDetailKey] [nvarchar](10) NULL,
         [TaskManagerReasonKey] [nvarchar](10) NULL,
         [Notes] [nvarchar](4000) NULL,
         [MoveRefKey] [nvarchar](10) NULL DEFAULT (''),
         [WIP_Refno] [nvarchar](30) NULL DEFAULT (''),
         [Channel_ID] [bigint] NULL DEFAULT ((0)))
   END    

   --Validation
   IF @n_continue IN(1,2)
   BEGIN
   	  SELECT TOP 1 @c_Storerkey = O.Storerkey,
   	         @c_Facility = O.Facility
   	  FROM LOADPLANDETAIL LPD (NOLOCK)
   	  JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
   	  WHERE LPD.Loadkey = @cLoadkey
   	     	
    	SELECT @c_CartonGroup = CartonGroup
      FROM STORER (NOLOCK)
      WHERE Storerkey = @c_Storerkey
   	
   	 IF EXISTS(SELECT 1
   	           FROM PACKHEADER PH (NOLOCK)
   	           JOIN PACKDETAIL PD (NOLOCK) ON PH.PickslipNo = PD.Pickslipno
   	           JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.Orderkey = LPD.Orderkey
   	           WHERE LPD.Loadkey = @cLoadkey)
   	 BEGIN
        SET @n_continue = 3
        SET @nErr = 82000
        SET @cErrmsg='NSQL'+CONVERT(NVARCHAR(5),@nErr)+': This Load was cartonized before. (ispLPPK12)'   	
        GOTO QUIT_SP 	
   	 END             	           

   	 IF NOT EXISTS(SELECT 1
   	               FROM CARTONIZATION CZ (NOLOCK)
   	               WHERE CZ.CartonizationGroup = @c_CartonGroup)
   	 BEGIN
        SET @n_continue = 3
        SET @nErr = 82010
        SET @cErrmsg='NSQL'+CONVERT(NVARCHAR(5),@nErr)+': CartonizationGroup ' + RTRIM(ISNULL(@c_CartonGroup,'')) + ' is not setup yet. (ispLPPK12)'   	
        GOTO QUIT_SP 	
   	 END             	
   	 
   	 SET @c_CartonType = ''
   	 SELECT TOP 1 @c_CartonType = CartonType
   	 FROM CARTONIZATION (NOLOCK)
   	 WHERE CartonizationGroup = @c_CartonGroup
   	 AND (Cube = 0 OR MaxWeight = 0)
   	 AND CartonType NOT IN('DRYHEAVY','TANK') 
   	 ORDER BY CartonType
     
     IF ISNULL(@c_CartonType,'') <> ''
     BEGIN
        SET @n_continue = 3
        SET @nErr = 82020
        SET @cErrmsg='NSQL'+CONVERT(NVARCHAR(5),@nErr)+': Cube and MaxWeight must setup for carton type ' + RTRIM(@c_CartonType) + '. (ispLPPK12)'   	
        GOTO QUIT_SP 	
     END        	    	 
   	 
   	 SET @c_Sku = ''
   	 SELECT TOP 1 @c_Sku = OD.Sku
   	 FROM LOADPLANDETAIL LPD (NOLOCK)
   	 JOIN ORDERDETAIL OD (NOLOCK) ON LPD.Orderkey = OD.Orderkey
   	 JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
     LEFT JOIN CARTONIZATION CZ (NOLOCK) ON SKU.Busr5 = CZ.CartonType AND CZ.CartonizationGroup = @c_CartonGroup
     WHERE LPD.Loadkey = @cLoadkey   	    	            
     AND CZ.CartonType IS NULL
     AND ISNULL(SKU.Busr5,'') <> ''
     ORDER BY OD.Sku

     IF ISNULL(@c_Sku,'') <> ''
     BEGIN
        SET @n_continue = 3
        SET @nErr = 82030
        SET @cErrmsg='NSQL'+CONVERT(NVARCHAR(5),@nErr)+': Busr5(CartonType) of Sku ' + RTRIM(@c_Sku) + ' is not valid. (ispLPPK12)'   	
        GOTO QUIT_SP 	
     END     

   	 SET @c_Sku = ''
   	 SELECT TOP 1 @c_Sku = OD.Sku
   	 FROM LOADPLANDETAIL LPD (NOLOCK)
   	 JOIN ORDERDETAIL OD (NOLOCK) ON LPD.Orderkey = OD.Orderkey
   	 JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
     WHERE LPD.Loadkey = @cLoadkey   	    	            
     AND SKU.Busr5 NOT IN('DRYHEAVY','TANK') 
     AND (SKU.StdCube = 0 OR SKU.StdGrossWgt = 0)
     ORDER BY OD.Sku

     IF ISNULL(@c_Sku,'') <> ''
     BEGIN
        SET @n_continue = 3
        SET @nErr = 82040
        SET @cErrmsg='NSQL'+CONVERT(NVARCHAR(5),@nErr)+': StdCube and StdGrossWgt must setup for Sku ' + RTRIM(@c_Sku) + '. (ispLPPK12)'   	
        GOTO QUIT_SP 	
     END     

   END
   
   --Initialize Pickdetail work in progress staging table    
   IF @n_continue IN(1,2)
   BEGIN   	  
      EXEC isp_CreatePickdetail_WIP
           @c_Loadkey               = @cLoadkey
          ,@c_Wavekey               = ''
          ,@c_WIP_RefNo             = @c_SourceType
          ,@c_PickCondition_SQL     = ''
          ,@c_Action                = 'I'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
          ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
          ,@b_Success               = @bSuccess OUTPUT
          ,@n_Err                   = @nErr     OUTPUT
          ,@c_ErrMsg                = @cErrMsg  OUTPUT

      IF @bSuccess <> 1
      BEGIN
         SET @n_continue = 3
      END
   END

   --Prepare common data
   IF @n_continue IN(1,2)
   BEGIN   	                        
   	  CREATE TABLE #ORDERSKU (RowID     INT IDENTITY(1,1) PRIMARY KEY,   --ORDERDETAIL by SKU, Cartontype and busr7
   	                          Orderkey  NVARCHAR(10), 
   	                          Storerkey NVARCHAR(15), 
   	                          Sku NVARCHAR(20),
   	                          CartonType NVARCHAR(10),
   	                          SkuBusr7   NVARCHAR(30),
   	                          TotalQty  INT,   	                          
                              TotalCube   DECIMAL(16,9),
                              TotalWeight DECIMAL(16,9),
   	                          TotalQtyPacked  INT,   	                          
                              TotalCubePacked   DECIMAL(16,9),
                              TotalWeightPacked DECIMAL(16,9),
                              MinPickZone       NVARCHAR(10),
                              MinLogicalLoc     NVARCHAR(18),
                              CaseCnt           INT,
                              InnerPack        INT)
      CREATE INDEX IDX_ORDERSKU_ORD ON #ORDERSKU (Orderkey)                              
                              
      CREATE TABLE #CARTONIZATION (RowID              INT IDENTITY(1,1) PRIMARY KEY,
                                   CartonizationGroup NVARCHAR(10), 
                                   CartonType   NVARCHAR(10),         
                                   Cube         DECIMAL(16,9),              
                                   MaxWeight    DECIMAL(16,9),         
                                   MaxCount     INT,
                                   MaxSku       INT,
                                   CartonLength DECIMAL(16,9),      
                                   CartonWidth  DECIMAL(16,9),      
                                   CartonHeight DECIMAL(16,9))                                    
                                   
      CREATE TABLE #CARTON (RowID       INT IDENTITY(1,1) PRIMARY KEY,
                            Orderkey    NVARCHAR(10), 
                            CartonNo    INT,
                            LabelNo     NVARCHAR(20),
                            CartonGroup NVARCHAR(10),
                            CartonType  NVARCHAR(10),
                            MaxCube     DECIMAL(16,9),                            
                            MaxWeight   DECIMAL(16,9),
                            MaxCount    INT,
                            MaxSku      INT) 
      CREATE INDEX IDX_CTN ON #CARTON (Orderkey)                              

      CREATE TABLE #CARTONDETAIL (RowID       INT IDENTITY(1,1) PRIMARY KEY,
                                  Orderkey    NVARCHAR(10), 
                                  CartonNo    INT, 
                                  Storerkey   NVARCHAR(15), 
                                  Sku         NVARCHAR(20), 
                                  Qty         INT, 
                                  RowRef      INT)  ----#ORDERSKU.RowID              
      CREATE INDEX IDX_CTNDET ON #CARTONDETAIL (Orderkey, CartonNo)                                                               
                                                               	                           	     	        
      SELECT @c_RLWAV_Opt5 = SC.Option5
      FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '', 'LPGenPackFromPicked') AS SC 
            
      SELECT @c_CartonItemOptimize = dbo.fnc_GetParamValueFromString('@c_CartonItemOptimize', @c_RLWAV_Opt5, @c_CartonItemOptimize)        
            
      --Cartonization info
      INSERT INTO #CARTONIZATION (CartonizationGroup,
                                  CartonType,
                                  Cube,
                                  MaxWeight,
                                  MaxCount,
                                  MaxSku,
                                  CartonLength,
                                  CartonWidth,
                                  CartonHeight)
      SELECT CZ.CartonizationGroup, CZ.CartonType, 
             CASE WHEN CZ.CartonType IN ('DRYHEAVY','TANK') THEN 9999999
                  ELSE CZ.Cube END AS Cube,   
             CASE WHEN CZ.CartonType IN ('DRYHEAVY','TANK') THEN 9999999
                  ELSE CZ.MaxWeight END AS MaxWeight,             
             CASE WHEN CZ.CartonType = 'DRYHEAVY' THEN 1
                  WHEN CZ.CartonType = 'TANK' THEN 10
                  ELSE 9999999 END AS MaxCount,             
             CASE WHEN CZ.CartonType IN ('DRYHEAVY','TANK') THEN 1
                  ELSE 9999999 END AS MaxSku,                  
             ISNULL(CZ.CartonLength,0), ISNULL(CZ.CartonWidth,0), ISNULL(CZ.CartonHeight,0)       
      FROM CARTONIZATION CZ (NOLOCK)                                                                       
      WHERE CartonizationGroup = @c_CartonGroup         
      
      IF @b_debug = 1
        SELECT * FROM #CARTONIZATION                                                                                           
              
      --Order sku info
      INSERT INTO #ORDERSKU (Orderkey, Storerkey, Sku, CartonType, SkuBusr7, TotalQty, TotalCube, TotalWeight, TotalQtyPacked, TotalCubePacked, TotalWeightpacked, MinPickZone, MinLogicalLoc, CaseCnt, InnerPack)
      SELECT PD.Orderkey, PD.Storerkey, PD.Sku, ISNULL(SKU.Busr5,''),
             CASE SKU.Busr7 
                WHEN '1' THEN 'DRY'
                WHEN '2' THEN 'WET'
                WHEN '3' THEN 'MILK'
                WHEN '6' THEN 'SAMPLE'
                WHEN '7' THEN 'PREMIUM'
                WHEN '8' THEN 'BUNDLE'
                WHEN 'KITT SET' THEN 'BUNDLE'
                WHEN '9' THEN 'STICKER'
                ELSE SKU.Busr7
             END AS Busr7,
             SUM(PD.Qty),
             SUM(PD.Qty * SKU.StdCube) ,
             SUM(PD.Qty * SKU.StdGrosswgt),
             0,0,0,
             MIN(LOC.PickZone),
             MIN(LOC.LogicalLocation),
             PACK.CaseCnt,
             PACK.InnerPack
       FROM #PICKDETAIL_WIP PD
       JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
       JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
       JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
       GROUP BY PD.Orderkey, PD.Storerkey, PD.Sku, ISNULL(SKU.Busr5,''),
                CASE SKU.Busr7 
                   WHEN '1' THEN 'DRY'
                   WHEN '2' THEN 'WET'
                   WHEN '3' THEN 'MILK'
                   WHEN '6' THEN 'SAMPLE'
                   WHEN '7' THEN 'PREMIUM'
                   WHEN '8' THEN 'BUNDLE'
                   WHEN 'KITT SET' THEN 'BUNDLE'
                   WHEN '9' THEN 'STICKER'
                   ELSE SKU.Busr7
                END,
                PACK.CaseCnt,
                PACK.InnerPack
       ORDER BY PD.Orderkey, MIN(LOC.PickZone), MIN(LOC.LogicalLocation), ISNULL(SKU.Busr5,''), 5, Sku

       IF @b_debug = 1
         SELECT * FROM #ORDERSKU                                                                                           
   END

   --Build carton
   IF @n_continue IN(1,2)
   BEGIN
   	  DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	     SELECT DISTINCT Orderkey
   	     FROM #ORDERSKU 
   	     ORDER BY Orderkey
   	  
   	  OPEN CUR_ORD
   	  
   	  FETCH NEXT FROM CUR_ORD INTO @c_Orderkey
   	  
   	  WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2) 
   	  BEGIN      	     
     	   SET @c_NewCarton = 'Y'
     	   SET @n_CartonNo = 0

         --pack full carton qty
         WHILE 1=1 AND @n_continue IN(1,2) 
         BEGIN         	  	                                                          
            SELECT TOP 1 @n_RowID = OS.RowID,
                   @c_Sku = OS.SKU,
                   @n_StdCube = SKU.StdCube,
                   @n_StdGrossWgt = SKU.StdGrossWgt,
                   @n_PackQty = OS.TotalQty - OS.TotalQtyPacked,
                   @n_CaseCnt = OS.CaseCnt,
                   @c_CartonType = OS.CartonType,
                   @c_SkuBusr7 = OS.SkuBusr7
            FROM #ORDERSKU OS (NOLOCK)
            JOIN SKU (NOLOCK) ON OS.Storerkey = SKU.Storerkey AND OS.Sku = SKU.Sku
            WHERE OS.Orderkey = @c_Orderkey
            AND OS.CaseCnt <= (OS.TotalQty - OS.TotalQtyPacked)
            AND OS.CaseCnt > 0
            AND OS.CartonType NOT IN('DRYHEAVY','TANK')
            ORDER BY OS.RowID 
                                      	 	 
            IF @@ROWCOUNT = 0 
            BEGIN      	 	    	    
               BREAK      	
            END
            
            SET @n_CartonNo = @n_CartonNo + 1
            
            IF ISNULL(@c_CartonType,'') = ''
            BEGIN
         	     SELECT TOP 1 @c_CartonType = CZ.CartonType
         	     FROM CODELKUP CL (NOLOCK)
         	     JOIN #CARTONIZATION CZ ON CL.Code = CZ.CartonType
         	     WHERE CL.ListName = 'CARTONTYPE'
         	     AND CL.Code2 = @c_SKUBusr7
         	     ORDER BY CL.Short 

               IF @c_CartonType = ''
         	  	 BEGIN
                 SET @n_continue = 3
                 SET @nErr = 82050
                 SET @cErrmsg='NSQL'+CONVERT(NVARCHAR(5),@nErr)+': Unable to find Carton type for Busr7: ' + RTRIM(@c_SkuBusr7) + '.(ispLPPK12)'
                 BREAK      	 	 	     	
         	  	 END      	 	 	           	 	 	              	     
         	  END		     
            
         	  --Get carton setup
         	  SELECT @n_CartonMaxCube = CZ.Cube,
         	         @n_CartonMaxWeight = CZ.MaxWeight,
         	         @n_CartonMaxCount = CZ.MaxCount,
         	         @n_CartonMaxSku = CZ.MaxSku
         	  FROM #CARTONIZATION CZ (NOLOCK)
         	  WHERE CZ.CartonType = @c_CartonType
         	  
         	  INSERT INTO #CARTON (Orderkey, CartonNo, LabelNo, CartonGroup, CartonType, MaxCube, MaxWeight, MaxCount, MaxSku)
         	  VALUES (@c_Orderkey, @n_CartonNo, '', @c_CartonGroup, @c_CartonType, @n_CartonMaxCube, @n_CartonMaxWeight, @n_CartonMaxCount, @n_CartonMaxSku)         	                 	  	 
            
         	  INSERT INTO #CARTONDETAIL (Orderkey, Storerkey, Sku, CartonNo, Qty, RowRef)  --refer to ORDERSKU.RowID
         	  VALUES (@c_Orderkey, @c_Storerkey, @c_Sku, @n_CartonNo, @n_CaseCnt, @n_RowID) 
         	       	       	 
         	  UPDATE #ORDERSKU 
         	  SET TotalQtyPacked = TotalQtyPacked + @n_CaseCnt, 
         	      TotalCubePacked = TotalCubePacked + (@n_CaseCnt * @n_StdCube),
         	      TotalWeightPacked = TotalWeightPacked + (@n_CaseCnt * @n_StdGrossWgt)
         	  WHERE RowID = @n_RowID           	   	 	 
         END
                                      
         --pack loose carton
         DECLARE CUR_ORDCTNGROUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT O.CartonType, O.SkuBusr7, 
                   SUM(O.TotalCube - O.TotalCubePacked), SUM(O.TotalWeight - O.TotalWeightpacked), SUM(O.TotalQty - O.TotalQtyPacked)
            FROM #ORDERSKU O
            WHERE O.Orderkey = @c_Orderkey
            AND O.TotalQty - O.TotalQtyPacked > 0
            GROUP BY O.CartonType, O.SkuBusr7
            ORDER BY MIN(O.MinPickZone), MIN(O.MinLogicalLoc), O.SkuBusr7, O.CartonType
         
         OPEN CUR_ORDCTNGROUP
         
         FETCH NEXT FROM CUR_ORDCTNGROUP INTO @c_CartonType, @c_SkuBusr7, @n_OrderCube, @n_OrderWeight, @n_OrderQty     
         
         SET @n_CartonNo = 0
         WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)  --pack by order, cartontype, busr7
         BEGIN
         	  SET @c_NewCarton = 'Y'
         	  SET @c_CurrCartonType = @c_CartonType
         	           	  
         	  WHILE 1=1 AND @n_continue IN(1,2) AND @n_OrderQty > 0
         	  BEGIN    
         	  	  SELECT @c_SKU = '', @n_StdCube = 0, @n_StdGrossWgt = 0
         	  	  SELECT @n_QtyCanPackByCube = 0, @n_QtyCanPackByWgt = 0, @n_QtyCanPackByCount = 0, @n_QtyCanPack = 0
               
   	            --Check sku limit per carton   	       
         	      IF (SELECT COUNT(DISTINCT Sku)
         	          FROM #CARTONDETAIL  
         	          WHERE Orderkey = @c_Orderkey
         	          AND CartonNo = @n_CartonNo) >= @n_CartonMaxSku
         	      BEGIN
         	         SET @c_NewCarton = 'Y'
         	      END      	         	  
         	  	        	 	 
         	  	  IF @c_NewCarton = 'Y' --new carton
         	  	  BEGIN      	 	 	  
         	  	  	 SELECT @n_CartonMaxCube = 0, @n_CartonMaxWeight = 0, @n_CartonMaxCount = 0, @c_NewCarton = 'N', @n_CartonNo = 0
               
                   SELECT @n_CartonNo = MAX(CartonNo)
                   FROM #CARTON
                   WHERE Orderkey = @c_Orderkey
                   
                   SET @n_CartonNo = ISNULL(@n_CartonNo,0)
                         	 	 	        	 	 	  
         	  	  	 SET @n_CartonNo = @n_CartonNo + 1
         	  	  	 
         	  	  	 --if no carton type set for the sku get from codelkup
         	  	  	 IF @c_CartonType = ''
         	  	  	 BEGIN
         	  	  	 	 SET @c_CurrCartonType = ''
         	  	  	 	 
         	  	  	    SELECT TOP 1 @c_CurrCartonType = CZ.CartonType
         	  	  	    FROM CODELKUP CL (NOLOCK)
         	  	  	    JOIN #CARTONIZATION CZ ON CL.Code = CZ.CartonType
         	  	  	    WHERE CL.ListName = 'CARTONTYPE'
         	  	  	    AND CL.Code2 = @c_SKUBusr7
         	  	  	    AND CZ.Cube >= @n_OrderCube
         	  	  	    AND CZ.MaxWeight >= @n_OrderWeight
         	  	  	    ORDER BY CZ.Cube, CL.Short
         	  	  	    
         	  	  	    IF @c_CurrCartonType = ''
         	  	  	    BEGIN
         	  	  	       SELECT TOP 1 @c_CurrCartonType = CZ.CartonType
         	  	  	       FROM CODELKUP CL (NOLOCK)
         	  	  	       JOIN #CARTONIZATION CZ ON CL.Code = CZ.CartonType
         	  	  	       WHERE CL.ListName = 'CARTONTYPE'
         	  	  	       AND CL.Code2 = @c_SKUBusr7
         	  	  	       ORDER BY CZ.Cube DESC, CL.Short
         	  	  	    END
         	  	  	    
         	  	  	    IF @c_CurrCartonType = ''
         	  	  	    BEGIN
                        SET @n_continue = 3
                        SET @nErr = 82060
                        SET @cErrmsg='NSQL'+CONVERT(NVARCHAR(5),@nErr)+': Unable to find Carton type for Busr7: ' + RTRIM(@c_SkuBusr7) + '.(ispLPPK12)'
                        BREAK      	 	 	     	
         	  	  	    END      	 	 	                   	  	  	    
         	  	  	 END
         	  	  	 
         	  	  	 --Get carton setup
         	  	  	 SELECT @n_CartonMaxCube = CZ.Cube,
         	  	  	        @n_CartonMaxWeight = CZ.MaxWeight,
         	  	  	        @n_CartonMaxCount = CZ.MaxCount,
         	  	  	        @n_CartonMaxSku = CZ.MaxSku
         	  	  	 FROM #CARTONIZATION CZ (NOLOCK)
         	  	  	 WHERE CZ.CartonType = @c_CurrCartonType
         	  	  	 
         	  	  	 INSERT INTO #CARTON (Orderkey, CartonNo, LabelNo, CartonGroup, CartonType, MaxCube, MaxWeight, MaxCount, MaxSku)
         	  	  	 VALUES (@c_Orderkey, @n_CartonNo, '', @c_CartonGroup, @c_CurrCartonType, @n_CartonMaxCube, @n_CartonMaxWeight, @n_CartonMaxCount, @n_CartonMaxSku)
         	  	  END
         	  	  
         	  	  --Get item to pack
         	  	  SET @n_RowID = 0
         	  	  
         	  	  WHILE @n_QtyCanPack = 0 AND @n_continue IN(1,2)  --Try search all items of the order that can fit the remaining space of the carton, priority by Sku 
         	  	  BEGIN
         	  	     SELECT TOP 1 @n_RowID = OS.RowID,
         	  	            @c_Sku = OS.SKU,
         	  	            @n_StdCube = SKU.StdCube,
         	  	            @n_StdGrossWgt = SKU.StdGrossWgt,
         	  	            @n_PackQty = OS.TotalQty - OS.TotalQtyPacked,
         	  	            @n_Innerpack = OS.Innerpack
         	  	     FROM #ORDERSKU OS (NOLOCK)
         	  	     JOIN SKU (NOLOCK) ON OS.Storerkey = SKU.Storerkey AND OS.Sku = SKU.Sku
         	  	     WHERE OS.Orderkey = @c_Orderkey
         	  	     AND OS.TotalQty - OS.TotalQtyPacked > 0
         	  	     AND OS.CartonType = @c_CartonType   --need to use original cartontype to search 
         	  	     AND OS.SkuBusr7 = @c_SkuBusr7
         	  	     AND OS.RowID > @n_RowID
         	  	     ORDER BY OS.RowID 
                                            	 	 
         	  	     IF @@ROWCOUNT = 0
         	  	     BEGIN      	 	    	    
         	  	        BREAK      	
         	  	     END
         	  	              	  	     
         	  	    --Validate the carton at lease can fit 1 qty of the sku
         	        IF NOT EXISTS(SELECT 1 FROM #CARTONIZATION WHERE Cube >= @n_StdCube AND CartonType = @c_CurrCartonType) 
         	           AND @c_CurrCartonType NOT IN('DRYHEAVY','TANK')
         	        BEGIN
                      SET @n_continue = 3
                      SET @nErr = 82070
                      SET @cErrmsg='NSQL'+CONVERT(NVARCHAR(5),@nErr)+': No Carton type can fit a Sku ' + RTRIM(@c_Sku) + '.(ispLPPK12)'
                      BREAK
         	        END      	         
         	        
         	        IF @n_InnerPack > 0
         	        BEGIN
         	           IF NOT EXISTS(SELECT 1 FROM #CARTONIZATION WHERE Cube >= (@n_StdCube * @n_InnerPack) AND CartonType = @c_CurrCartonType) 
         	              AND @c_CurrCartonType NOT IN('DRYHEAVY','TANK')
         	           BEGIN
                         SET @n_continue = 3
                         SET @nErr = 82071
                         SET @cErrmsg='NSQL'+CONVERT(NVARCHAR(5),@nErr)+': No Carton type can fit a InnerPack Sku ' + RTRIM(@c_Sku) + '.(ispLPPK12)'
                         BREAK
         	           END      	         
         	        END
         	        
         	  	     --Caclulate pack qty
         	  	     IF @n_StdCube > 0
                     SET @n_QtyCanPackByCube = FLOOR(@n_CartonMaxCube / @n_StdCube)
         	  	     
   	 	             IF @n_StdGrossWgt > 0
             	        SET @n_QtyCanPackByWgt = FLOOR(@n_CartonMaxWeight / @n_StdGrossWgt)
               
         	        SET @n_QtyCanPackByCount = @n_CartonMaxCount
         	  	     
         	  	     IF @n_QtyCanPackByWgt = 0 AND @n_StdGrossWgt > 0
         	  	        SET @n_QtyCanPack = 0
         	  	     ELSE IF @n_QtyCanPackByCube > @n_QtyCanPackByWgt AND @n_QtyCanPackByWgt > 0  --Check if over weight get qty by weight limitation.
         	  	        SET @n_QtyCanPack = @n_QtyCanPackByWgt
         	  	     ELSE IF @n_QtyCanPackByCube > 0
         	  	        SET @n_QtyCanPack = @n_QtyCanPackByCube
         	  	      
         	  	     IF @n_StdCube = 0 AND @n_StdGrossWgt = 0 --if sku cube and weight not setup just pack all qty
         	  	        SET @n_QtyCanPack = @n_PackQty
         	  	        
         	  	     IF @n_QtyCanPack > @n_QtyCanPackByCount --check if have qty limit get qty limit
         	  	        SET @n_QtyCanPack = @n_QtyCanPackByCount
         	  	        
         	  	     IF @n_PackQty < @n_QtyCanPack
         	  	        SET @n_QtyCanPack = @n_PackQty
         	  	        
         	  	     IF @n_Innerpack > 0
         	  	     BEGIN
         	  	        SET @n_QtyCanPack = FLOOR(@n_QtyCanPack / @n_Innerpack) * @n_InnerPack
         	  	     END
         	  	                 	  	     
         	  	     IF @c_CartonItemOptimize <> 'Y'
         	  	        BREAK --if current item cannot fit current carton open new carton and not search for other/next item. 
         	      END
         	  	           	  	  
         	  	  IF @n_continue = 3
         	  	     BREAK
         	  	     
         	  	  IF @n_QtyCanPack = 0  --carton full 
         	  	  BEGIN
         	  	     SET @c_NewCarton = 'Y'
         	  	     GOTO NEXT_CTNORSKU
         	  	  END
         	  	        	 	       	 	 
         	  	  --Pack to Carton
         	  	  INSERT INTO #CARTONDETAIL (Orderkey, Storerkey, Sku, CartonNo, Qty, RowRef)  --refer to ORDERSKU.RowID
         	  	  VALUES (@c_Orderkey, @c_Storerkey, @c_Sku, @n_CartonNo, @n_QtyCanPack, @n_RowID) 
         	  	  
         	  	  --Update counters
         	  	  SET @n_OrderCube = @n_OrderCube - (@n_QtyCanPack * @n_StdCube)
         	  	  SET @n_OrderWeight = @n_OrderWeight - (@n_QtyCanPack * @n_StdGrossWgt)
         	  	  SET @n_OrderQty = @n_OrderQty - @n_QtyCanPack
         	  	  SET @n_CartonMaxCube = @n_CartonMaxCube - (@n_QtyCanPack * @n_StdCube)
         	  	  SET @n_CartonMaxWeight = @n_CartonMaxWeight - (@n_QtyCanPack * @n_StdGrossWgt)
         	  	  SET @n_CartonMaxCount = @n_CartonMaxCount - @n_QtyCanPack
         	  	        	 
         	  	  UPDATE #ORDERSKU
         	  	  SET TotalQtyPacked = TotalQtyPacked + @n_QtyCanPack, 
         	  	      TotalCubePacked = TotalCubePacked + (@n_QtyCanPack * @n_StdCube),
         	  	      TotalWeightPacked = TotalWeightPacked + (@n_QtyCanPack * @n_StdGrossWgt)
         	  	  WHERE RowID = @n_RowID      	 	       
         	  	       	 	       	 	      	 	 
          	  	NEXT_CTNORSKU:  	 	       	 	 
         	  END
             
            FETCH NEXT FROM CUR_ORDCTNGROUP INTO @c_CartonType, @c_SkuBusr7, @n_OrderCube, @n_OrderWeight, @n_OrderQty 
         END
         CLOSE CUR_ORDCTNGROUP
         DEALLOCATE CUR_ORDCTNGROUP

         FETCH NEXT FROM CUR_ORD INTO @c_Orderkey       
      END
      CLOSE CUR_ORD
      DEALLOCATE CUR_ORD
   END
   
   --Create pickslip
   IF @n_continue IN(1,2)
   BEGIN
      EXEC isp_CreatePickSlip
             @c_Loadkey = @cLoadkey
            ,@c_PickslipType = ''      
            ,@c_ConsolidateByLoad  = 'N'
            ,@c_Refkeylookup       = 'N'    
            ,@c_LinkPickSlipToPick = 'Y'    
            ,@c_AutoScanIn         = 'N'    
            ,@b_Success            = @bSuccess OUTPUT
            ,@n_Err                = @nErr     OUTPUT
            ,@c_ErrMsg             = @cErrMsg  OUTPUT
      
      IF @bSuccess <> 1
         SET @n_Continue = 3         	
   END
   
   --Create packing records
   IF @n_continue IN(1,2)
   BEGIN   	
      DECLARE CUR_PACKORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT DISTINCT CT.Orderkey, PH.PickHeaderkey
        FROM #CARTON CT
        JOIN #CARTONDETAIL CTD ON CT.Orderkey = CTD.Orderkey AND CT.CartonNo = CTD.CartonNo
        JOIN PICKHEADER PH (NOLOCK) ON CT.Orderkey = PH.Orderkey
        ORDER BY CT.Orderkey

      OPEN CUR_PACKORDER

      FETCH NEXT FROM CUR_PACKORDER INTO @c_Orderkey, @c_Pickslipno
                 
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)  --get order       
      BEGIN             	 
         --Create packheader
         IF NOT EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE Pickslipno = @c_Pickslipno)
	       BEGIN
            INSERT INTO PACKHEADER (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
                   SELECT TOP 1 O.Route, O.Orderkey, '', O.LoadKey, '',O.Storerkey, @c_PickSlipNo
                   FROM  PICKHEADER PH (NOLOCK)
                   JOIN  Orders O (NOLOCK) ON (PH.Orderkey = O.Orderkey)
                   WHERE PH.PickHeaderKey = @c_PickSlipNo
         
            SET @nErr = @@ERROR
            
            IF @nErr <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @cErrmsg = CONVERT(NVARCHAR(250),@nErr), @nErr = 82080
               SELECT @cErrmsg='NSQL'+CONVERT(NVARCHAR(5),@nErr)+': Error Insert Packheader Table (ispLPPK12)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@cErrmsg) + ' ) '
            END
	       END
      	
         DECLARE CUR_PACKCARTON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
            SELECT DISTINCT CT.CartonNo, CT.CartonType
            FROM #CARTON CT
            JOIN #CARTONDETAIL CTD ON CT.Orderkey = CTD.Orderkey AND CT.CartonNo = CTD.CartonNo
            WHERE CT.Orderkey = @c_Orderkey
            ORDER BY CT.CartonNo
         
         OPEN CUR_PACKCARTON
         
         FETCH NEXT FROM CUR_PACKCARTON INTO @n_CartonNo, @c_CartonType
                    
         WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)  --get Carton
         BEGIN            
         	  --Get labelno
         	  SET @c_LabelNo = ''
         	  /*
         	  EXEC isp_GenUCCLabelNo_Std
               @cPickslipNo = @c_Pickslipno,
               @nCartonNo   = @n_CartonNo,
               @cLabelNo    = @c_LabelNo  OUTPUT,
               @b_success   = @bSuccess  OUTPUT,
               @n_err       = @nErr      OUTPUT,
               @c_errmsg    = @cErrmsg   OUTPUT  	             
            
            IF @bSuccess <> 1
               SET @n_continue = 3
            */   
            SELECT @c_KeyName = 'LPK12_'+ CONVERT(NVARCHAR,GETDATE(),112) 
            
            EXEC dbo.nspg_GetKey                
               @KeyName = @c_KeyName
              ,@fieldlength = 4
              ,@keystring = @c_LabelNo OUTPUT    
              ,@b_Success = @bsuccess OUTPUT    
              ,@n_err = @nerr OUTPUT    
              ,@c_errmsg = @cErrmsg OUTPUT
              ,@b_resultset = 0    
              ,@n_batch     = 1               
              
            IF @bsuccess <> 1
            BEGIN              
               SELECT @n_continue = 3
            END
            ELSE
            BEGIN  
               SELECT @c_LabelNo = 'RC' + CONVERT(NVARCHAR,GETDATE(),112) + @c_LabelNo                              
               
               IF (SELECT COUNT(DISTINCT Keyname) 
                   FROM NCOUNTER (NOLOCK)
                   WHERE KeyName <> @c_KeyName
                   AND LEFT(KeyName,6) = 'LPK12_') > 30
               BEGIN          
                  DELETE FROM NCOUNTER          
                  WHERE KeyName <> @c_KeyName
                  AND LEFT(KeyName,6) = 'LPK12_'               
               END
            END

            --Update labelno to #CARTON
            UPDATE #CARTON 
            SET LabelNo = @c_LabelNo
            WHERE Orderkey = @c_Orderkey
            AND CartonNo = @n_CartonNo             
            
            --Get packed carton cube,qty,weight            
             SELECT @n_TotCartonQty = 0, @n_TotCartonCube = 0, @n_TotCartonWeight = 0
             SELECT @n_TotCartonQty  = SUM(CTD.Qty), 
                    @n_TotCartonCube = SUM(CTD.Qty * SKU.StdCube),
                    @n_TotCartonWeight = SUM(CTD.Qty * SKU.StdGrossWgt)
             FROM #CARTONDETAIL CTD
             JOIN SKU (NOLOCK) ON CTD.Storerkey = SKU.Storerkey AND CTD.Sku = SKU.Sku
             WHERE CTD.Orderkey = @c_Orderkey
             AND CTD.CartonNo = @n_CartonNo

            --Create packinfo            
            IF EXISTS (SELECT 1 FROM PACKINFO(NOLOCK) WHERE Pickslipno = @c_PickslipNo
   	                       AND CartonNo = @n_CartonNo)
   	        BEGIN
   	        	 DELETE FROM PACKINFO WHERE Pickslipno = @c_PickslipNo AND CartonNo = @n_CartonNo
   	        END               

   	        INSERT INTO PACKINFO (Pickslipno, CartonNo, CartonType, Cube, Weight, Qty)
   	        VALUES (@c_PickslipNo, @n_CartonNo, @c_CartonType, @n_TotCartonCube, @n_TotCartonWeight, @n_TotCartonQty)
            
            SET @nErr = @@ERROR
            IF @nErr <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @cErrmsg = CONVERT(NVARCHAR(250),@nErr), @nErr = 82090
               SELECT @cErrmsg='NSQL'+CONVERT(NVARCHAR(5),@nErr)+': Error Insert Packinfo Table (ispLPPK12)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@cErrmsg) + ' ) '
            END   
            
            DECLARE CUR_PACKSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
               SELECT CTD.Storerkey, CTD.Sku, SUM(CTD.Qty)
               FROM #CARTON CT
               JOIN #CARTONDETAIL CTD ON CT.Orderkey = CTD.Orderkey AND CT.CartonNo = CTD.CartonNo
               WHERE CT.Orderkey = @c_Orderkey
               AND CTD.CartonNo = @n_CartonNo
               GROUP BY CTD.Storerkey, CTD.Sku

            OPEN CUR_PACKSKU
           
            FETCH NEXT FROM CUR_PACKSKU INTO @c_Storerkey, @c_Sku, @n_PackQty

            WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)  --get sku
            BEGIN            
               -- CartonNo and LabelLineNo will be inserted by trigger
               INSERT INTO PACKDETAIL (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, Refno, DropId)
               VALUES (@c_PickSlipNo, 0, @c_LabelNo, '00000', @c_StorerKey, @c_SKU,
                       @n_PackQty, sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), '', @c_LabelNo)
               
               SET @nErr = @@ERROR
               IF @nErr <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @cErrmsg = CONVERT(NVARCHAR(250),@nErr), @nErr = 82100
                  SELECT @cErrmsg='NSQL'+CONVERT(NVARCHAR(5),@nErr)+': Error Insert Packdetail Table (ispLPPK12)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@cErrmsg) + ' ) '
               END
            	
               FETCH NEXT FROM CUR_PACKSKU INTO @c_Storerkey, @c_Sku, @n_PackQty           	
            END
            CLOSE CUR_PACKSKU
            DEALLOCATE CUR_PACKSKU
                                                   	  
            FETCH NEXT FROM CUR_PACKCARTON INTO @n_CartonNo, @c_CartonType
         END
         CLOSE CUR_PACKCARTON
         DEALLOCATE CUR_PACKCARTON      
         
         FETCH NEXT FROM CUR_PACKORDER INTO @c_Orderkey, @c_Pickslipno         
      END         	      
      CLOSE CUR_PACKORDER 
      DEALLOCATE CUR_PACKORDER
   END
   
   --Update labelno to pickdetail caseid
   IF @n_continue IN(1,2)
   BEGIN            
   	  UPDATE #PICKDETAIL_WIP SET CaseID = ''
   	  
      DECLARE CUR_LABELUPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT CT.Orderkey, CTD.Storerkey, CTD.Sku, CTD.Qty, CT.LabelNo
         FROM #CARTON CT
         JOIN #CARTONDETAIL CTD ON CT.Orderkey = CTD.Orderkey AND CT.CartonNo = CTD.CartonNo
         ORDER BY CT.Orderkey, CT.CartonNo, CTD.Storerkey, CTD.Sku

      OPEN CUR_LABELUPD

      FETCH NEXT FROM CUR_LABELUPD INTO @c_Orderkey, @c_Storerkey, @c_Sku, @n_PackQty, @c_LabelNo
                 
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2) 
      BEGIN             	    	
         DECLARE CUR_PICKDET_UPDATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.PickDetailKey, PD.Qty
            FROM #PICKDETAIL_WIP PD (NOLOCK) 
            JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
            JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
            JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
            WHERE PD.Orderkey = @c_Orderkey
            AND PD.Storerkey = @c_Storerkey
            AND PD.Sku = @c_Sku
            AND ISNULL(PD.CaseID,'') = ''
            ORDER BY CASE WHEN PD.Qty >= @n_PackQty AND @n_PackQty = PACK.CaseCnt THEN 1 ELSE 2 END, LOC.PickZone, LOC.LogicalLocation, PD.PickDetailKey
         
         OPEN CUR_PICKDET_UPDATE
         
         FETCH NEXT FROM CUR_PICKDET_UPDATE INTO @c_PickDetailKey, @n_PickdetQty
         
         WHILE @@FETCH_STATUS <> -1 AND @n_packqty > 0
         BEGIN
            IF @n_PickdetQty <= @n_packqty
            BEGIN
            	 UPDATE #PICKDETAIL_WIP WITH (ROWLOCK)
            	 SET CaseId = @c_labelno,
            	     UOMQty = CASE WHEN UOM = '6' THEN Qty ELSE UOMQty END
            	 WHERE PickDetailKey = @c_PickDetailKey
         
		         	 SELECT @n_packqty = @n_packqty - @n_PickdetQty
            END
            ELSE
            BEGIN  -- pickqty > packqty
            	 SELECT @n_splitqty = @n_PickdetQty - @n_packqty
            	 
	             EXECUTE nspg_GetKey
               'PICKDETAILKEY',
               10,
               @c_NewPickdetailkey OUTPUT,
               @bSuccess OUTPUT,
               @nErr OUTPUT,
               @cErrmsg OUTPUT
               
               IF NOT @bSuccess = 1
               BEGIN
               	  SELECT @n_continue = 3
               END
         
            	 INSERT #PICKDETAIL_WIP
                      (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                       Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
                       DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                       ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                       WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, Taskdetailkey, TaskManagerReasonkey, Notes, WIP_Refno, Channel_ID)
               SELECT @c_newpickdetailkey, '', PD.PickHeaderKey, PD.OrderKey, PD.OrderLineNumber, PD.Lot,
                      PD.Storerkey, PD.Sku, PD.AltSku, PD.UOM, 
                      CASE WHEN PD.UOM = '6' THEN @n_splitqty 
                           WHEN PD.UOM = '2' AND PACK.CaseCnt > 0 AND @n_splitqty % CAST(IIF(PACK.CaseCnt > 0, PACK.casecnt, 1) AS INT) = 0 THEN FLOOR(@n_splitqty / PACK.CaseCnt) 
                      ELSE PD.UOMQty END , 
                      @n_splitqty, PD.QtyMoved, PD.Status,
                      PD.DropID, PD.Loc, PD.ID, PD.PackKey, PD.UpdateSource, PD.CartonGroup, PD.CartonType,
                      PD.ToLoc, PD.DoReplenish, PD.ReplenishZone, PD.DoCartonize, PD.PickMethod,
                      PD.WaveKey, PD.EffectiveDate, '9', PD.ShipFlag, PD.PickSlipNo, PD.Taskdetailkey, PD.TaskManagerReasonkey, PD.Notes, PD.WIP_Refno, PD.Channel_ID
               FROM #PickDetail_WIP PD (NOLOCK)
               JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
               JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
               WHERE PD.PickDetailKey = @c_PickDetailKey
                  
               UPDATE #PICKDETAIL_WIP 
            	 SET #PICKDETAIL_WIP.CaseId = @c_labelno,
            	     #PICKDETAIL_WIP.Qty = @n_packqty,
            	     #PICKDETAIL_WIP.UOMQty = 
                   CASE WHEN #PICKDETAIL_WIP.UOM = '6' THEN @n_packqty 
                        WHEN #PICKDETAIL_WIP.UOM = '2' AND PACK.CaseCnt > 0 AND @n_packqty % CAST(IIF(PACK.CaseCnt > 0, PACK.casecnt, 1) AS INT) = 0 THEN FLOOR(@n_packqty / PACK.CaseCnt) 
                   ELSE #PICKDETAIL_WIP.UOMQty END 
		         	     --UOMQTY = CASE UOM WHEN '6' THEN @n_packqty ELSE UOMQty END
		         	 FROM #PICKDETAIL_WIP 
               JOIN SKU (NOLOCK) ON #PICKDETAIL_WIP .Storerkey = SKU.Storerkey AND #PICKDETAIL_WIP .Sku = SKU.Sku
               JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
            	 WHERE #PICKDETAIL_WIP.PickDetailKey = @c_PickDetailKey
         
               SELECT @n_packqty = 0
            END
            FETCH NEXT FROM CUR_PICKDET_UPDATE INTO @c_PickDetailKey, @n_PickdetQty
         END
         CLOSE CUR_PICKDET_UPDATE
         DEALLOCATE CUR_PICKDET_UPDATE   
   
         FETCH NEXT FROM CUR_LABELUPD INTO @c_Orderkey, @c_Storerkey, @c_Sku, @n_PackQty, @c_LabelNo              
      END               
      CLOSE CUR_LABELUPD
      DEALLOCATE CUR_LABELUPD     
   END
   
   -----Update pickdetail_WIP work in progress staging table back to pickdetail    
   IF @n_continue IN(1,2)
   BEGIN
      EXEC isp_CreatePickdetail_WIP
            @c_Loadkey               = @cLoadkey
           ,@c_Wavekey               = ''
           ,@c_WIP_RefNo             = @c_SourceType
           ,@c_PickCondition_SQL     = ''
           ,@c_Action                = 'U'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
           ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
           ,@b_Success               = @bSuccess OUTPUT
           ,@n_Err                   = @nErr     OUTPUT
           ,@c_ErrMsg                = @cErrMsg  OUTPUT

      IF @bSuccess <> 1
      BEGIN
         SET @n_continue = 3
      END
   END    

QUIT_SP:

   IF OBJECT_ID('tempdb..#PICKDETAIL_WIP') IS NOT NULL
      DROP TABLE #PICKDETAIL_WIP
   IF OBJECT_ID('tempdb..#ORDERSKU') IS NOT NULL
      DROP TABLE #ORDERSKU
   IF OBJECT_ID('tempdb..#CARTONIZATION') IS NOT NULL
      DROP TABLE #CARTONIZATION
   IF OBJECT_ID('tempdb..#CARTON') IS NOT NULL
      DROP TABLE #CARTON
   IF OBJECT_ID('tempdb..#CARTONDETAIL') IS NOT NULL
         DROP TABLE #CARTONDETAIL

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @bSuccess = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @nErr, @cErrMsg, 'ispLPPK12'
      
      IF @b_debug = 1
        RAISERROR (@cErrmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @bSuccess = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO