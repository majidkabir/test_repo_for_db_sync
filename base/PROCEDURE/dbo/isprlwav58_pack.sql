SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: ispRLWAV58_PACK                                         */
/* Creation Date: 2023-04-18                                            */
/* Copyright: MAERSK                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-22210 SG-AESOP Release Wave - Cartonization             */
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
/* 18-APR-2023 NJOW     1.0   DEVOPS Combine Script                     */
/* 29-AUG-2023 NJOW01   1.1   WMS-22210  Add item lenght & height       */ 
/*                            validation                                */
/************************************************************************/
CREATE   PROC [dbo].[ispRLWAV58_PACK]
           @c_Wavekey                 NVARCHAR(10)
         , @b_Success                 INT            OUTPUT
         , @n_Err                     INT            OUTPUT
         , @c_ErrMsg                  NVARCHAR(255)  OUTPUT
         , @n_debug                   INT            = 0
AS                                    
BEGIN                                 
   SET NOCOUNT ON                     
   SET ANSI_NULLS OFF                 
   SET QUOTED_IDENTIFIER OFF          
   SET CONCAT_NULL_YIELDS_NULL OFF    
                                      
   DECLARE @c_SourceType              NVARCHAR(30)
          ,@n_StartTCnt               INT          = 0
          ,@n_Continue                INT          = 1
          ,@c_isB2C                   NVARCHAR(1)  = 'N'
          ,@c_CartonGroup             NVARCHAR(10) = ''
          ,@c_Storerkey               NVARCHAR(15) 
          ,@c_Facility                NVARCHAR(5)
          ,@c_RLWAV_Opt5              NVARCHAR(4000)
          ,@c_NewCarton               NVARCHAR(1)
          ,@n_CartonNo                INT
          ,@c_CartonType              NVARCHAR(10)
          ,@n_CartonMaxCube           DECIMAL(13,6)
          ,@n_CartonMaxWeight         DECIMAL(13,6)
          ,@c_Orderkey                NVARCHAR(10)
          ,@n_OrderCube               DECIMAL(13,6)
          ,@n_OrderWeight             DECIMAL(13,6)                        
          ,@n_RowID                   INT
          ,@n_OrderQty                INT
          ,@n_UnPackQty               INT
          ,@n_PKRowID                 INT
          ,@n_RowRef                  INT
          ,@c_UOM                     NVARCHAR(10)
          ,@c_Sku                     NVARCHAR(20)
          ,@n_CartonQty               INT
          ,@n_LooseQty                INT
          ,@n_TotalItemCube           DECIMAL(13,6)
          ,@n_TotalItemWeight         DECIMAL(13,6)
          ,@n_EA_Cube                 DECIMAL(13,6)
          ,@n_EA_Weight               DECIMAL(13,6)
          ,@n_CN_Cube                 DECIMAL(13,6)
          ,@n_CN_Weight               DECIMAL(13,6)
          ,@n_CaseCnt                 INT
          ,@n_QtyCanPackByCube        INT
          ,@n_QtyCanPackByWgt         INT
          ,@n_QtyCanPack              INT
          ,@c_PickslipNo              NVARCHAR(10)
          ,@c_LabelNo                 NVARCHAR(20)
          ,@n_TotCartonCube           DECIMAL(13,6)
          ,@n_TotCartonWeight         DECIMAL(13,6)
          ,@n_TotCartonQty            INT
          ,@n_PackQty                 INT      
          ,@n_PickdetQty              INT
          ,@c_PickDetailKey           NVARCHAR(10)
          ,@c_NewPickDetailKey        NVARCHAR(10)
          ,@n_SplitQty                INT
          ,@c_CartonItemPosFitCheck   NVARCHAR(30) = 'Y'
          ,@c_CartonItemOptimize      NVARCHAR(30) = 'Y'
             
   SELECT @n_StartTCnt = @@TRANCOUNT, @n_Continue = 1, @b_Success = 1, @n_err = 0, @c_errmsg = '', @c_SourceType = 'ispRLWAV58_PACK'
   
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
   
   --Intializtion
   IF @n_continue IN(1,2)
   BEGIN
      SELECT TOP 1 @c_isB2C = CASE WHEN O.DocType = 'E' THEN 'Y' ELSE 'N' END,
             @c_Storerkey = O.Storerkey,
             @c_Facility = O.Facility
      FROM WAVEDETAIL WD (NOLOCK) 
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
      WHERE WD.Wavekey = @c_Wavekey

    	SELECT @c_CartonGroup = CartonGroup
      FROM STORER (NOLOCK)
      WHERE Storerkey = @c_Storerkey

      SELECT @c_RLWAV_Opt5 = SC.Option5
      FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '', 'ReleaseWave_SP') AS SC 
      
      IF @c_isB2C = 'N'
      BEGIN         
         SELECT @c_CartonGroup = dbo.fnc_GetParamValueFromString('@c_CartonGroup_B2B', @c_RLWAV_Opt5, @c_CartonGroup)   
      END
      
      SELECT @c_CartonItemPosFitCheck = dbo.fnc_GetParamValueFromString('@c_CartonItemPosFitCheck', @c_RLWAV_Opt5, @c_CartonItemPosFitCheck)   
      SELECT @c_CartonItemOptimize = dbo.fnc_GetParamValueFromString('@c_CartonItemOptimize', @c_RLWAV_Opt5, @c_CartonItemOptimize)      	
   END  
 
   --Validation
   IF @n_continue IN(1,2)
   BEGIN
   	 IF EXISTS(SELECT 1
   	           FROM PACKHEADER PH (NOLOCK)
   	           JOIN PACKDETAIL PD (NOLOCK) ON PH.PickslipNo = PD.Pickslipno
   	           JOIN WAVEDETAIL WD (NOLOCK) ON PH.Orderkey = WD.Orderkey
   	           WHERE WD.Wavekey = @c_Wavekey)
   	 BEGIN
        SET @n_continue = 3
        SET @n_Err = 82000
        SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This wave was cartonized before. (ispRLWAV58_PACK)'   	
        GOTO QUIT_SP 	
   	 END            	     
   	 
   	 IF EXISTS(SELECT 1 
               FROM CARTONIZATION CZ (NOLOCK)                                                                       
               WHERE CartonizationGroup = @c_CartonGroup                   
               AND (CZ.CartonLength = 0 OR CZ.CartonWidth = 0 AND CZ.CartonHeight = 0))
     BEGIN
        SET @n_continue = 3
        SET @n_Err = 82010
        SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Carton Length, Width or Height is not setup at carton group ' + RTRIM(@c_CartonGroup) + '. (ispRLWAV58_PACK)'   	
        GOTO QUIT_SP 	
     END             	       
     
     SET @c_Sku = ''
     SELECT TOP 1 @c_Sku = OD.Sku
     FROM WAVEDETAIL WD (NOLOCK)
     JOIN ORDERDETAIL OD (NOLOCK) ON WD.Orderkey = OD.Orderkey
     JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
     WHERE WD.Wavekey = @c_Wavekey    
     AND (SKU.StdGrossWgt = 0 OR SKU.GrossWgt = 0)
     ORDER BY OD.Sku

     IF ISNULL(@c_Sku,'') <> ''
     BEGIN
        SET @n_continue = 3
        SET @n_Err = 82020
        SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': StdGrossWgt(piece) or GrossWgt(carton) is not setup for Sku ' + RTRIM(@c_Sku) + '. (ispRLWAV58_PACK)'   	
        GOTO QUIT_SP 	
     END             	                 

     SET @c_Sku = ''
     SELECT TOP 1 @c_Sku = OD.Sku
     FROM WAVEDETAIL WD (NOLOCK)
     JOIN ORDERDETAIL OD (NOLOCK) ON WD.Orderkey = OD.Orderkey
     JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
     JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
     WHERE WD.Wavekey = @c_Wavekey    
     AND (PACK.LengthUOM3 = 0 OR PACK.WidthUOM3 = 0 OR PACK.HeightUOM3 = 0 OR
          PACK.LengthUOM1 = 0 OR PACK.WidthUOM1 = 0 OR PACK.HeightUOM1 = 0)
     ORDER BY OD.Sku

     IF ISNULL(@c_Sku,'') <> ''
     BEGIN
        SET @n_continue = 3
        SET @n_Err = 82030
        SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Lenght, Width or Height is not setup for piece or carton pack of Sku ' + RTRIM(@c_Sku) + '. (ispRLWAV58_PACK)'   	
        GOTO QUIT_SP 	
     END             	                 
   END
   
   --Initialize Pickdetail work in progress staging table    
   IF @n_continue IN(1,2)
   BEGIN   	  
      EXEC isp_CreatePickdetail_WIP
           @c_Loadkey               = ''
          ,@c_Wavekey               = @c_wavekey
          ,@c_WIP_RefNo             = @c_SourceType
          ,@c_PickCondition_SQL     = ''
          ,@c_Action                = 'I'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
          ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
          ,@b_Success               = @b_Success OUTPUT
          ,@n_Err                   = @n_Err     OUTPUT
          ,@c_ErrMsg                = @c_ErrMsg  OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END      
   END
   
   --Prepare common data
   IF @n_continue IN(1,2)
   BEGIN
   	  CREATE TABLE #SKUDIM (RowID     INT IDENTITY(1,1) PRIMARY KEY,
   	                        Storerkey NVARCHAR(15),
   	                        Sku       NVARCHAR(20),
   	                        EA_Length DECIMAL(13,6),
   	                        EA_Width  DECIMAL(13,6),
   	                        EA_Height DECIMAL(13,6),
   	                        EA_Weight DECIMAL(13,6),
   	                        EA_Cube   DECIMAL(13,6),
   	                        CN_Length DECIMAL(13,6),
   	                        CN_Width  DECIMAL(13,6),
   	                        CN_Height DECIMAL(13,6),
   	                        CN_Weight DECIMAL(13,6),
   	                        CN_Cube   DECIMAL(13,6),
   	                        CaseCnt   INT)
      CREATE INDEX IDX_SKU ON #SKUDIM (Storerkey, Sku)                              
   	                        
   	  CREATE TABLE #ORDERSKU (RowID     INT IDENTITY(1,1) PRIMARY KEY,   --ORDERDETAIL by SKU and UOM
   	                          Orderkey  NVARCHAR(10), 
   	                          Storerkey NVARCHAR(15), 
   	                          Sku NVARCHAR(20),
   	                          UOM NVARCHAR(10), 
   	                          TotalQty  INT,   	                          
                              CartonQty INT,
                              LooseQty  INT,
                              TotalCube   DECIMAL(13,6),
                              TotalWeight DECIMAL(13,6),
   	                          TotalQtyPacked  INT,   	                          
                              CartonQtyPacked INT,   --for uom = 2
                              LooseQtyPacked  INT,   --for uom <> 2
                              TotalCubePacked   DECIMAL(13,6),
                              TotalWeightPacked DECIMAL(13,6))                  
      CREATE INDEX IDX_ORD ON #ORDERSKU (Orderkey)                              
                              
      CREATE TABLE #CARTONIZATION (RowID              INT IDENTITY(1,1) PRIMARY KEY,
                                   CartonizationGroup NVARCHAR(10), 
                                   CartonType   NVARCHAR(10),         
                                   Cube         DECIMAL(13,6),              
                                   MaxWeight    DECIMAL(13,6),         
                                   CartonLength DECIMAL(13,6),      
                                   CartonWidth  DECIMAL(13,6),      
                                   CartonHeight DECIMAL(13,6))                                    
                                   
      CREATE TABLE #OptimizeItemToPack (ID          INT           IDENTITY(1,1),
                                        Storerkey   NVARCHAR(15)  NOT NULL DEFAULT(''), 
                                        SKU         NVARCHAR(20)  NOT NULL DEFAULT(''),
                                        Dim1        DECIMAL(10,6) NOT NULL DEFAULT(0.00),
                                        Dim2        DECIMAL(10,6) NOT NULL DEFAULT(0.00),
                                        Dim3        DECIMAL(10,6) NOT NULL DEFAULT(0.00),
                                        Quantity    INT           NOT NULL DEFAULT(0),
                                        RowRef      INT           NOT NULL DEFAULT(0),  --#CARTONDETAIL.RowID
                                        OriginalQty INT           NOT NULL DEFAULT(0))          
                                        
      CREATE TABLE #OptimizeResult (ContainerID       NVARCHAR(10),
                                    AlgorithmID       NVARCHAR(10),
                                    IsCompletePack    NVARCHAR(10),
                                    ID                INT,   --OptimizeItemToPack.ID
                                    SKU               NVARCHAR(20),
                                    Qty               INT)

      CREATE TABLE #CARTON (RowID       INT IDENTITY(1,1) PRIMARY KEY,
                            Orderkey    NVARCHAR(10), 
                            CartonNo    INT,
                            LabelNo     NVARCHAR(20),
                            CartonGroup NVARCHAR(10),
                            CartonType  NVARCHAR(10),
                            MaxCube     DECIMAL(13,6),
                            MaxWeight   DECIMAL(13,6)) 
      CREATE INDEX IDX_CTN ON #CARTON (Orderkey)                              

      CREATE TABLE #CARTONDETAIL (RowID       INT IDENTITY(1,1) PRIMARY KEY,
                                  Orderkey    NVARCHAR(10), 
                                  CartonNo    INT, 
                                  Storerkey   NVARCHAR(15), 
                                  Sku         NVARCHAR(20), 
                                  UOM         NVARCHAR(10), 
                                  Qty         INT, 
                                  RowRef      INT)  ----#ORDERSKU.RowID              
      CREATE INDEX IDX_CTNDET ON #CARTONDETAIL (Orderkey, CartonNo)                                                               
                                                               	                           	     	              
      --Cartonization info
      INSERT INTO #CARTONIZATION (CartonizationGroup,
                                  CartonType,
                                  Cube,
                                  MaxWeight,
                                  CartonLength,
                                  CartonWidth,
                                  CartonHeight)
      SELECT CZ.CartonizationGroup, CZ.CartonType, 
             dbo.fnc_CalculateCube(CZ.CartonLength,  CZ.CartonWidth, CZ.CartonHeight, 'CM', 'M', ''),  --convert to cubic meter
             20, ISNULL(CZ.CartonLength,0), ISNULL(CZ.CartonWidth,0), ISNULL(CZ.CartonHeight,0)       --carton max weight fix to 20kg
      FROM CARTONIZATION CZ (NOLOCK)                                                                       
      WHERE CartonizationGroup = @c_CartonGroup                                                                                                    
      
      --Sku dimention info
      INSERT INTO #SKUDIM (Storerkey, Sku, 
                           EA_Length, EA_Width, EA_Height, EA_Weight, EA_Cube,   --EA is for piece measurement
                           CN_Length, CN_Width, CN_Height, CN_Weight, CN_Cube, CaseCnt)  --CN is for full carton measurement
      SELECT DISTINCT PD.Storerkey, PD.Sku, PACK.LengthUOM3, PACK.WidthUOM3, PACK.HeightUOM3, SKU.StdGrossWgt, 
             dbo.fnc_CalculateCube(PACK.LengthUOM3,  PACK.WidthUOM3, PACK.HeightUOM3, 'CM','M',''),
             PACK.LengthUOM1, PACK.WidthUOM1, PACK.HeightUOM1, SKU.GrossWgt, 
             dbo.fnc_CalculateCube(PACK.LengthUOM1,  PACK.WidthUOM1, PACK.HeightUOM1, 'CM','M',''),
             PACK.CaseCnt
      FROM #PickDetail_WIP PD
      JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
      JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey      
      
      --Order sku info
      INSERT INTO #ORDERSKU (Orderkey, Storerkey, Sku, UOM, TotalQty, CartonQty, LooseQty, TotalCube, TotalWeight, TotalQtyPacked, CartonQtyPacked, LooseQtyPacked, TotalCubePacked, TotalWeightpacked)
      SELECT ORDSKU.Orderkey, ORDSKU.Storerkey, ORDSKU.Sku, ORDSKU.UOM, ORDSKU.TotalQty, 
             ORDSKU.CartonQty, ORDSKU.LooseQty, 
             CASE WHEN ORDSKU.UOM = '2' THEN ORDSKU.CartonQty * SD.CN_Cube ELSE ORDSKU.LooseQty * SD.EA_Cube END AS TotalCube,    --full carton and piece using different measurement
             CASE WHEN ORDSKU.UOM = '2' THEN ORDSKU.CartonQty * SD.CN_Weight ELSE ORDSKU.LooseQty * SD.EA_Weight END AS TotalWeight, 
             0,0,0,0,0                        
      FROM (            
             SELECT PD.Orderkey, PD.Storerkey, PD.Sku, PD.UOM, SUM(PD.Qty) AS TotalQty, 
                    CASE WHEN PD.UOM = '2' THEN FLOOR(SUM(PD.Qty) / SD.CaseCnt) ELSE 0 END AS CartonQty,
                    CASE WHEN PD.UOM <> '2' THEN SUM(PD.Qty) ELSE 0 END AS LooseQty                    
             FROM #PickDetail_WIP PD
             JOIN #SKUDIM SD ON PD.Storerkey = SD.Storerkey AND PD.Sku = SD.Sku
             GROUP BY PD.Orderkey, PD.Storerkey, PD.Sku, PD.UOM, SD.Casecnt      
           ) AS ORDSKU  
      JOIN #SKUDIM SD ON SD.Storerkey = ORDSKU.Storerkey AND SD.Sku = ORDSKU.Sku              
      ORDER BY ORDSKU.Orderkey, ORDSKU.UOM, ORDSKU.Sku
      
      IF NOT EXISTS(SELECT 1 FROM Codelkup WITH (NOLOCK)  --Cartonization API configuration
                WHERE Listname = 'WebService'
                AND Code = 'Cartonization')
         SET @c_CartonItemPosFitCheck = 'N'          
      
      --NJOW01 S   
      IF @c_CartonItemPosFitCheck = 'Y'
      BEGIN
         SET @c_Sku = ''
         SELECT TOP 1 @c_Sku = SD.Sku
         FROM #ORDERSKU OS
         JOIN #SKUDIM SD ON OS.Storerkey = SD.Storerkey AND OS.Sku = SD.Sku
         OUTER APPLY (SELECT TOP 1 CZ.CartonType
                      FROM #CARTONIZATION CZ
                      WHERE CZ.CartonLength >= SD.CN_Length
                      AND CZ.CartonHeight >= SD.CN_Height) CTN
         WHERE CTN.CartonType IS NULL             
         AND OS.UOM = '2'
         ORDER BY SD.Sku
         
         IF ISNULL(@c_Sku,'') <> ''
         BEGIN
            SET @n_continue = 3
            SET @n_Err = 82032
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Unable find any carton type can fit Lenght and Height of Sku ' + RTRIM(@c_Sku) + ' (By Carton). (ispRLWAV58_PACK)'   	
            GOTO QUIT_SP 	
         END       
         
         SET @c_Sku = ''
         SELECT TOP 1 @c_Sku = SD.Sku
         FROM #ORDERSKU OS
         JOIN #SKUDIM SD ON OS.Storerkey = SD.Storerkey AND OS.Sku = SD.Sku
         OUTER APPLY (SELECT TOP 1 CZ.CartonType
                      FROM #CARTONIZATION CZ
                      WHERE CZ.CartonLength >= SD.EA_Length
                      AND CZ.CartonHeight >= SD.EA_Height) CTN
         WHERE CTN.CartonType IS NULL             
         AND OS.UOM <> '2'
         ORDER BY SD.Sku
         
         IF ISNULL(@c_Sku,'') <> ''
         BEGIN
            SET @n_continue = 3
            SET @n_Err = 82034
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Unable find any carton type can fit Lenght and Height of Sku ' + RTRIM(@c_Sku) + ' (By Piece). (ispRLWAV58_PACK)'   	
            GOTO QUIT_SP 	
         END                
      END   	                 
      --NJOW01 E             
   END

   --Build carton
   IF @n_continue IN(1,2)
   BEGIN
      DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT O.Orderkey, SUM(O.TotalCube), SUM(O.TotalWeight), SUM(O.TotalQty)
         FROM #ORDERSKU O
         GROUP BY O.Orderkey
      
      OPEN CUR_ORD

      FETCH NEXT FROM CUR_ORD INTO @c_Orderkey, @n_OrderCube, @n_OrderWeight, @n_OrderQty     
      
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)  --pack by order
      BEGIN
      	 SET @c_NewCarton = 'Y'
      	 SET @n_CartonNo = 0
      	 
      	 WHILE 1=1 AND @n_continue IN(1,2) AND @n_OrderQty > 0
      	 BEGIN          	 	 
    	 	 	 SELECT @c_UOM = '', @c_Sku = '', @n_CartonQty = 0, @n_LooseQty = 0, @n_TotalItemCube = 0, @n_TotalItemWeight = 0
      	 	 SELECT @n_EA_Cube = 0, @n_CN_Weight = 0, @n_EA_Cube = 0, @n_EA_Weight = 0, @n_CaseCnt = 0
      	 	 SELECT @n_QtyCanPackByCube = 0, @n_QtyCanPackByWgt = 0, @n_QtyCanPack = 0
      	 	 SELECT @n_UnPackQty = 0, @n_PKRowID = 0, @n_RowRef = 0
      	 	 
      	 	 IF @c_NewCarton = 'Y' --new carton
      	 	 BEGIN      	 	 	  
      	 	 	  SELECT @c_CartonType = '', @n_CartonMaxCube = 0, @n_CartonMaxWeight = 0, @c_NewCarton = 'N'

              SELECT @n_CartonNo = MAX(CartonNo)
              FROM #CARTON
              WHERE Orderkey = @c_Orderkey
              
              SET @n_CartonNo = ISNULL(@n_CartonNo,0)
                    	 	 	        	 	 	  
      	 	 	  SET @n_CartonNo = @n_CartonNo + 1
      	 	 	  
      	 	 	  --Find carton best fit order remaining cube
      	 	 	  SELECT TOP 1 @c_CartonType = CZ.CartonType,
      	 	 	         @n_CartonMaxCube = CZ.Cube,
      	 	 	         @n_CartonMaxWeight = CZ.MaxWeight
      	 	 	  FROM #CARTONIZATION CZ (NOLOCK)
      	 	 	  WHERE Cube >= @n_OrderCube
      	 	 	  ORDER BY CZ.Cube
      	 	 	  
      	 	 	  --Find biggest carton if best fit not found
      	 	 	  IF ISNULL(@c_CartonType,'') = ''
      	 	 	  BEGIN
      	 	 	     SELECT TOP 1 @c_CartonType = CZ.CartonType,
      	 	 	            @n_CartonMaxCube = CZ.Cube,
         	 	 	          @n_CartonMaxWeight = CZ.MaxWeight
      	 	 	     FROM #CARTONIZATION CZ (NOLOCK)
      	 	 	     ORDER BY CZ.Cube DESC
      	 	 	  END      	 	 	        	      	

      	 	 	  INSERT INTO #CARTON (Orderkey, CartonNo, LabelNo, CartonGroup, CartonType, MaxCube, MaxWeight)
      	 	 	  VALUES (@c_Orderkey, @n_CartonNo, '', @c_CartonGroup, @c_CartonType, @n_CartonMaxCube, @n_CartonMaxWeight)
      	 	 END
      	 	 
      	 	 --Get item to pack
      	 	 SET @n_RowID = 0
      	 	 
      	 	 WHILE @n_QtyCanPack = 0 AND @n_continue IN(1,2)  --Try search all items of the order that can fit the remaining space of the carton, priority by UOM and Sku 
      	 	 BEGIN
      	 	    SELECT TOP 1 @n_RowID = OS.RowID,
      	 	           @c_UOM = OS.UOM,      	 	        
      	 	           @c_Sku = OS.SKU,
      	 	           @n_CartonQty = OS.CartonQty - OS.CartonQtyPacked,   --for UOM = 2
      	 	           @n_LooseQty = OS.LooseQty - OS.LooseQtyPacked,      --for UOM <> 2
      	 	           @n_TotalItemCube = OS.TotalCube - OS.TotalCubePacked,
      	 	           @n_TotalItemWeight = OS.TotalWeight - OS.TotalWeightPacked,
      	 	           @n_EA_Cube = SD.EA_Cube,
      	 	           @n_EA_Weight = SD.EA_Weight,
      	 	           @n_CN_Cube = SD.CN_Cube,
      	 	           @n_CN_Weight = SD.CN_Weight,
      	 	           @n_CaseCnt = SD.CaseCnt
      	 	    FROM #ORDERSKU OS
      	 	    JOIN #SKUDIM SD (NOLOCK) ON OS.Storerkey = SD.Storerkey AND OS.Sku = SD.Sku
      	 	    WHERE OS.Orderkey = @c_Orderkey
      	 	    AND OS.TotalQty - OS.TotalQtyPacked > 0
      	 	    AND OS.RowID > @n_RowID
      	 	    ORDER BY OS.RowID --OS.UOM, OS.Sku
                                       	 	 
      	 	    IF @@ROWCOUNT = 0
      	 	    BEGIN      	 	    	    
      	 	       BREAK      	
      	 	    END
      	 	    
      	 	    --Validate the carton at lease can fit 1 qty of the sku
      	 	    IF @c_UOM = '2' 
      	      BEGIN
      	         IF NOT EXISTS(SELECT 1 FROM #CARTONIZATION WHERE Cube >= @n_CN_Cube)
      	         BEGIN
                    SET @n_continue = 3
                    SET @n_Err = 82040
                    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No Carton type can fit full case Sku ' + RTRIM(@c_Sku) + '.(ispRLWAV58_PACK)'
                    BREAK
      	         END           	         
      	      END
      	      ELSE
      	      BEGIN
      	         IF NOT EXISTS(SELECT 1 FROM #CARTONIZATION WHERE Cube >= @n_EA_Cube)
      	         BEGIN
                    SET @n_continue = 3
                    SET @n_Err = 82050
                    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No Carton type can fit Sku ' + RTRIM(@c_Sku) + '.(ispRLWAV58_PACK)'
                    BREAK
      	         END      	         
      	      END      	 	             	 	    
      	 	    
      	 	    --Caclulate pack qty         	 	 
      	 	    IF @c_UOM = '2' --By carton
      	 	    BEGIN
      	 	    	  SET @n_QtyCanPackByCube = FLOOR(@n_CartonMaxCube / @n_CN_Cube)
      	 	    	  
      	 	    	  IF @n_CN_Weight > 0
      	 	    	     SET @n_QtyCanPackByWgt = FLOOR(@n_CartonMaxWeight / @n_CN_Weight)
      	 	    	  
      	 	    	  IF @n_QtyCanPackByWgt = 0
      	 	    	     SET @n_QtyCanPack = 0
      	 	    	  ELSE IF @n_QtyCanPackByCube > @n_QtyCanPackByWgt AND @n_QtyCanPackByWgt > 0 --cannot exceed max weight
      	 	    	     SET @n_QtyCanPack = @n_QtyCanPackByWgt
      	 	    	  ELSE
      	 	    	     SET @n_QtyCanPack = @n_QtyCanPackByCube
      	 	    	     
      	 	    	  IF @n_CartonQty < @n_QtyCanPack
      	 	    	     SET @n_QtyCanPack = @n_CartonQty
      	 	    	     
      	 	    	  SET @n_QtyCanPack = @n_QtyCanPack * @n_CaseCnt  --Convert from case to piece   
      	 	    END
      	 	    ELSE
      	 	    BEGIN  --By piece
      	 	    	  SET @n_QtyCanPackByCube = FLOOR(@n_CartonMaxCube / @n_EA_Cube)
      	 	    	  
      	 	    	  IF @n_EA_Weight > 0
         	    	 	   SET @n_QtyCanPackByWgt = FLOOR(@n_CartonMaxWeight / @n_EA_Weight)
      	 	    	  
      	 	    	  IF @n_QtyCanPackByWgt = 0
      	 	    	     SET @n_QtyCanPack = 0
      	 	    	  ELSE IF @n_QtyCanPackByCube > @n_QtyCanPackByWgt AND @n_QtyCanPackByWgt > 0 
      	 	    	     SET @n_QtyCanPack = @n_QtyCanPackByWgt
      	 	    	  ELSE
      	 	    	     SET @n_QtyCanPack = @n_QtyCanPackByCube
      	 	    	     
      	 	    	  IF @n_LooseQty < @n_QtyCanPack
      	 	    	     SET @n_QtyCanPack = @n_LooseQty
      	 	    END
      	 	    
      	 	    IF @c_CartonItemOptimize <> 'Y'
      	 	       BREAK --if current item cannot fit current carton open new carton and not search for other/next item. 
      	   END
      	 	 
      	 	 IF @n_continue = 3  --NJOW01
      	 	    BREAK
      	 	 
      	 	 IF @n_QtyCanPack = 0  --carton full 
      	 	 BEGIN
      	 	    SET @c_NewCarton = 'Y'
      	 	    GOTO NEXT_CTNORSKU
      	 	 END
      	 	       	 	 
      	 	 --Pack to Carton
      	 	 INSERT INTO #CARTONDETAIL (Orderkey, Storerkey, Sku, UOM, CartonNo, Qty, RowRef)  --refer to ORDERSKU.RowID
      	 	 VALUES (@c_Orderkey, @c_Storerkey, @c_Sku, @c_UOM, @n_CartonNo, @n_QtyCanPack, @n_RowID) 
      	 	 
      	 	 --Update counters
      	 	 IF @c_UOM = '2'
      	 	 BEGIN
      	 	    SET @n_OrderCube = @n_OrderCube - (FLOOR(@n_QtyCanPack / @n_CaseCnt) * @n_CN_Cube)
      	 	    SET @n_OrderWeight = @n_OrderWeight - (FLOOR(@n_QtyCanPack / @n_CaseCnt) * @n_CN_Weight)
      	 	    SET @n_OrderQty = @n_OrderQty - @n_QtyCanPack
      	 	    SET @n_CartonMaxCube = @n_CartonMaxCube - (FLOOR(@n_QtyCanPack / @n_CaseCnt) * @n_CN_Cube)
      	 	    SET @n_CartonMaxWeight = @n_CartonMaxWeight - (FLOOR(@n_QtyCanPack / @n_CaseCnt) * @n_CN_Weight)      	 	    
                                    	 	    
      	 	    UPDATE #ORDERSKU
      	 	    SET TotalQtyPacked = TotalQtyPacked + @n_QtyCanPack, 
      	 	        CartonQtyPacked = CartonQtyPacked + FLOOR(@n_QtyCanPack / @n_CaseCnt),
      	 	        TotalCubePacked = TotalCubePacked + (FLOOR(@n_QtyCanPack / @n_CaseCnt) * @n_CN_Cube),
      	 	        TotalWeightPacked = TotalWeightPacked + (FLOOR(@n_QtyCanPack / @n_CaseCnt) * @n_CN_Weight) 
      	 	    WHERE RowID = @n_RowID      	 	              	 	    
      	   END
      	   ELSE
      	   BEGIN
      	 	    SET @n_OrderCube = @n_OrderCube - (@n_QtyCanPack * @n_EA_Cube)
      	 	    SET @n_OrderWeight = @n_OrderWeight - (@n_QtyCanPack * @n_CN_Weight)
      	 	    SET @n_OrderQty = @n_OrderQty - @n_QtyCanPack
      	 	    SET @n_CartonMaxCube = @n_CartonMaxCube - (@n_QtyCanPack * @n_EA_Cube)
      	 	    SET @n_CartonMaxWeight = @n_CartonMaxWeight - (@n_QtyCanPack * @n_CN_Weight)

      	 	    UPDATE #ORDERSKU
      	 	    SET TotalQtyPacked = TotalQtyPacked + @n_QtyCanPack, 
      	 	        LooseQtyPacked = LooseQtyPacked + @n_QtyCanPack,
      	 	        TotalCubePacked = TotalCubePacked + (@n_QtyCanPack * @n_EA_Cube),
      	 	        TotalWeightPacked = TotalWeightPacked + (@n_QtyCanPack * @n_EA_Weight)
      	 	    WHERE RowID = @n_RowID      	 	              	 	    
      	 	 END          	 	 
      	 	 
       	 	 NEXT_CTNORSKU:  	 	
       	 	 
       	 	 IF (@c_NewCarton = 'Y' OR @n_OrderQty <= 0) AND @c_CartonItemPosFitCheck = 'Y'  --Close and optimize carton by cartonization API
       	 	 BEGIN       	 	     
              TRUNCATE TABLE #OptimizeItemToPack   

              --get full case pack of the carton
              INSERT INTO #OptimizeItemToPack (Storerkey, SKU, Dim1, Dim2, Dim3, Quantity, RowRef )  --refer to #CARTONDETAIL.RowID
              SELECT CTD.Storerkey, CTD.Sku, 
                     SD.CN_Length, SD.CN_Width, SD.CN_Height,                                   
                     FLOOR(CTD.Qty / SD.CaseCnt),  --convert to case
                     CTD.RowID
              FROM #CARTONDETAIL CTD
              JOIN #SKUDIM SD ON CTD.Storerkey = SD.Storerkey AND CTD.Sku = SD.Sku
              WHERE CTD.CartonNo = @n_CartonNo
              AND CTD.Orderkey = @c_Orderkey
              AND CTD.UOM = '2'
              
              --get loose pack of the carton
              INSERT INTO #OptimizeItemToPack (Storerkey, SKU, Dim1, Dim2, Dim3, Quantity, RowRef )  --refer to #CARTONDETAIL.RowID
              SELECT CTD.Storerkey, CTD.Sku, 
                     SD.EA_Length, SD.EA_Width, SD.EA_Height,                                   
                     CTD.Qty,
                     CTD.RowID
              FROM #CARTONDETAIL CTD
              JOIN #SKUDIM SD ON CTD.Storerkey = SD.Storerkey AND CTD.Sku = SD.Sku
              WHERE CTD.CartonNo = @n_CartonNo
              AND CTD.Orderkey = @c_Orderkey
              AND CTD.UOM <> '2'
                            	 	 	
              --optimize the carton
              TRUNCATE TABLE #OptimizeResult
              INSERT INTO #OptimizeResult (ContainerID, AlgorithmID, IsCompletePack, ID, SKU, Qty)
              EXEC isp_SubmitToCartonizeAPI
                   @c_CartonGroup = @c_CartonGroup
                 , @c_CartonType  = @c_CartonType
                 , @c_Algorithm   = 'Height'
                 , @b_Success     = @b_Success       OUTPUT
                 , @n_Err         = @n_Err           OUTPUT
                 , @c_ErrMsg      = @c_ErrMsg        OUTPUT
              
              IF @b_Success = 0
              BEGIN
                 SET @n_Continue = 3
                 SET @n_err = 82060
                 SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Error Executing isp_SubmitToCartonizeAPI. (ispRLWAV58_PACK)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                 BREAK
              END       	 	 	 
              ELSE IF EXISTS(SELECT 1 FROM #OptimizeResult WHERE IsCompletePack = 'FALSE') --some item failed to pack due to positioning issue
              BEGIN
              	 --Unpack failed full carton sku
              	 DECLARE CUR_UNPACK_FC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
              	    SELECT FLOOR(CTD.Qty / SD.CaseCnt) - ISNULL(R.Qty,0), CTD.RowId, CTD.RowRef,  --RowRef refer to #ORDERSKU.RowID
              	           SD.CN_Cube, SD.CN_Weight, SD.CaseCnt
              	    FROM #CARTONDETAIL CTD 
                    JOIN #SKUDIM SD ON CTD.Storerkey = SD.Storerkey AND CTD.Sku = SD.Sku                                        
               	    JOIN #OptimizeItemToPack OP ON CTD.RowID = OP.RowRef
              	    LEFT JOIN #OptimizeResult R ON OP.ID = R.ID
              	    WHERE CTD.UOM = '2'
              	    AND FLOOR(CTD.Qty / SD.CaseCnt) - ISNULL(R.Qty,0) > 0
              	    AND CTD.Orderkey = @c_Orderkey
              	    AND CTD.CartonNo = @n_CartonNo
              	                  	 
                 OPEN CUR_UNPACK_FC

                 FETCH NEXT FROM CUR_UNPACK_FC INTO @n_UnPackQty, @n_PKRowID, @n_RowRef, @n_CN_Cube, @n_CN_Weight, @n_CaseCnt
                 
                 WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)  
                 BEGIN              
                 	  --reverse the counters	                    	  
      	 	          SET @n_OrderCube = @n_OrderCube + (@n_UnPackQty * @n_CN_Cube)
      	 	          SET @n_OrderWeight = @n_OrderWeight + (@n_UnPackQty * @n_CN_Weight)
      	 	          SET @n_OrderQty = @n_OrderQty + (@n_UnPackQty * @n_CaseCnt)
       	 	          SET @n_CartonMaxCube = @n_CartonMaxCube + (@n_UnPackQty * @n_CN_Cube)
      	 	          SET @n_CartonMaxWeight = @n_CartonMaxWeight + (@n_UnPackQty * @n_CN_Weight)
                                    	 	    
      	 	          UPDATE #ORDERSKU
      	 	          SET TotalQtyPacked = TotalQtyPacked - (@n_UnPackQty * @n_CaseCnt), 
      	 	              CartonQtyPacked = CartonQtyPacked - @n_UnPackQty,
      	 	              TotalCubePacked = TotalCubePacked - (@n_UnPackQty * @n_CN_Cube),
      	 	              TotalWeightPacked = TotalWeightPacked - (@n_UnPackQty * @n_CN_Weight) 
      	 	          WHERE RowID = @n_RowRef      	 	
      	 	          
      	 	          UPDATE #CARTONDETAIL
      	 	          SET Qty = Qty - (@n_UnPackQty * @n_CaseCnt)        	 	    
      	 	          WHERE RowID = @n_PKRowID
      	 	          
      	 	          DELETE FROM #CARTONDETAIL WHERE RowID = @n_PKRowID AND Qty <= 0  --delete if 0 qty
                 	   
                    FETCH NEXT FROM CUR_UNPACK_FC INTO @n_UnPackQty, @n_PKRowID, @n_RowRef, @n_CN_Cube, @n_CN_Weight, @n_CaseCnt
                 END
                 CLOSE CUR_UNPACK_FC
                 DEALLOCATE CUR_UNPACK_FC
                 
              	 --Unpack failed loose sku
              	 DECLARE CUR_UNPACK_EA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
              	    SELECT CTD.Qty - ISNULL(R.Qty,0), CTD.RowId, CTD.RowRef,  --RowRef refer to #ORDERSKU.RowID
              	           SD.EA_Cube, SD.EA_Weight
              	    FROM #CARTONDETAIL CTD 
                    JOIN #SKUDIM SD ON CTD.Storerkey = SD.Storerkey AND CTD.Sku = SD.Sku                    
               	    JOIN #OptimizeItemToPack OP ON CTD.RowID = OP.RowRef
              	    LEFT JOIN #OptimizeResult R ON OP.ID = R.ID
              	    WHERE CTD.UOM <> '2'
              	    AND CTD.Qty - ISNULL(R.Qty,0) > 0
              	    AND CTD.Orderkey = @c_Orderkey
              	    AND CTD.CartonNo = @n_CartonNo
              	 
                 OPEN CUR_UNPACK_EA

                 FETCH NEXT FROM CUR_UNPACK_EA INTO @n_UnPackQty, @n_PKRowID, @n_RowRef, @n_EA_Cube, @n_EA_Weight
                 
                 WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)  
                 BEGIN              	        
                 	  --reverse the counters            	  
      	 	          SET @n_OrderCube = @n_OrderCube + (@n_UnPackQty * @n_EA_Cube)
      	 	          SET @n_OrderWeight = @n_OrderWeight + (@n_UnPackQty * @n_EA_Weight)
      	 	          SET @n_OrderQty = @n_OrderQty + @n_UnPackQty 
       	 	          SET @n_CartonMaxCube = @n_CartonMaxCube + (@n_UnPackQty * @n_EA_Cube)
      	 	          SET @n_CartonMaxWeight = @n_CartonMaxWeight + (@n_UnPackQty * @n_EA_Weight)
                                    	 	    
      	 	          UPDATE #ORDERSKU
      	 	          SET TotalQtyPacked = TotalQtyPacked - @n_UnPackQty, 
      	 	              LooseQtyPacked = LooseQtyPacked - @n_UnPackQty,
      	 	              TotalCubePacked = TotalCubePacked - (@n_UnPackQty * @n_EA_Cube),
      	 	              TotalWeightPacked = TotalWeightPacked - (@n_UnPackQty * @n_EA_Weight) 
      	 	          WHERE RowID = @n_RowRef      	 	
      	 	          
      	 	          UPDATE #CARTONDETAIL
      	 	          SET Qty = Qty - @n_UnPackQty   	 	    
      	 	          WHERE RowID = @n_PKRowID
      	 	          
      	 	          DELETE FROM #CARTONDETAIL WHERE RowID = @n_PKRowID AND Qty <= 0  --delete if 0 qty
                 	   
                    FETCH NEXT FROM CUR_UNPACK_EA INTO @n_UnPackQty, @n_PKRowID, @n_RowRef, @n_EA_Cube, @n_EA_Weight
                 END
                 CLOSE CUR_UNPACK_EA
                 DEALLOCATE CUR_UNPACK_EA   
                 
                 IF @n_OrderQty > 0 AND @c_NewCarton <> 'Y' --if last carton reversed need to open new carton
                    SET @c_NewCarton = 'Y'
              END  --IsCompletePack=FALSE                    	 	 	
       	 	 END --Close and Optimize carton
      	 END --@n_OrderQty > 0
         
         FETCH NEXT FROM CUR_ORD INTO @c_Orderkey, @n_OrderCube, @n_OrderWeight, @n_OrderQty 
      END
      CLOSE CUR_ORD
      DEALLOCATE CUR_ORD
   END
   
   --Create pickslip
   IF @n_continue IN(1,2)
   BEGIN
      EXEC isp_CreatePickSlip
             @c_Wavekey = @c_Wavekey   
            ,@c_PickslipType = ''      
            ,@c_ConsolidateByLoad  = 'N'
            ,@c_Refkeylookup       = 'N'    
            ,@c_LinkPickSlipToPick = 'Y'    
            ,@c_AutoScanIn         = 'N'    
            ,@b_Success            = @b_Success OUTPUT
            ,@n_Err                = @n_Err     OUTPUT
            ,@c_ErrMsg             = @c_ErrMsg  OUTPUT
      
      IF @b_success <> 1
         SET @n_Continue = 3         	
   END
   
   --Create packing records
   IF @n_continue IN(1,2)
   BEGIN   	
      DECLARE CUR_PACKORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT DISTINCT CT.Orderkey, PH.PickHeaderKey
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
         
            SET @n_err = @@ERROR
            
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82070
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Packheader Table (ispRLWAV58_PACK)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
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
         	  EXEC isp_GenUCCLabelNo_Std
               @cPickslipNo = @c_Pickslipno,
               @nCartonNo   = @n_CartonNo,
               @cLabelNo    = @c_LabelNo  OUTPUT,
               @b_success   = @b_success  OUTPUT,
               @n_err       = @n_err      OUTPUT,
               @c_errmsg    = @c_errmsg   OUTPUT  	             
            
            IF @b_success <> 1
               SET @n_continue = 3

            --Update labelno to #CARTON
            UPDATE #CARTON 
            SET LabelNo = @c_LabelNo
            WHERE Orderkey = @c_Orderkey
            AND CartonNo = @n_CartonNo             
            
            --Get packed carton cube,qty,weight            
             SELECT @n_TotCartonQty = 0, @n_TotCartonCube = 0, @n_TotCartonWeight = 0
             SELECT @n_TotCartonQty  = SUM(CTD.Qty), 
                    @n_TotCartonCube = SUM(CASE WHEN CTD.UOM = '2' THEN
                                                   FLOOR(CTD.Qty / SD.CaseCnt) * SD.CN_Cube
                                                ELSE CTD.Qty * SD.EA_Cube END) ,
                    @n_TotCartonWeight = SUM(CASE WHEN CTD.UOM = '2' THEN
                                                     FLOOR(CTD.Qty / SD.CaseCnt) * SD.CN_Weight
                                                  ELSE CTD.Qty * SD.EA_Weight END)
             FROM #CARTONDETAIL CTD
             JOIN #SKUDIM SD ON CTD.Storerkey = SD.Storerkey AND CTD.Sku = SD.Sku
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
            
            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82080
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Packinfo Table (ispRLWAV58_PACK)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
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
               INSERT INTO PACKDETAIL (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, Refno)
               VALUES (@c_PickSlipNo, 0, @c_LabelNo, '00000', @c_StorerKey, @c_SKU,
                       @n_PackQty, sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), '')
               
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82060
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Packdetail Table (ispRLWAV58_PACK)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
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
         SELECT CT.Orderkey, CTD.Storerkey, CTD.Sku, CTD.UOM, CTD.Qty, CT.LabelNo
         FROM #CARTON CT
         JOIN #CARTONDETAIL CTD ON CT.Orderkey = CTD.Orderkey AND CT.CartonNo = CTD.CartonNo
         ORDER BY CT.Orderkey, CTD.Storerkey, CTD.Sku, CTD.UOM

      OPEN CUR_LABELUPD

      FETCH NEXT FROM CUR_LABELUPD INTO @c_Orderkey, @c_Storerkey, @c_Sku, @c_UOM, @n_PackQty, @c_LabelNo
                 
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2) 
      BEGIN             	    	
         DECLARE CUR_PICKDET_UPDATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.PickDetailKey, PD.Qty
            FROM #PICKDETAIL_WIP PD (NOLOCK) 
            WHERE PD.Orderkey = @c_Orderkey
            AND PD.Storerkey = @c_Storerkey
            AND PD.Sku = @c_Sku
            AND PD.UOM = @c_UOM
            AND ISNULL(PD.CaseID,'') = ''
            ORDER BY PD.PickDetailKey
         
         OPEN CUR_PICKDET_UPDATE
         
         FETCH NEXT FROM CUR_PICKDET_UPDATE INTO @c_PickDetailKey, @n_PickdetQty
         
         WHILE @@FETCH_STATUS <> -1 AND @n_packqty > 0
         BEGIN
            IF @n_PickdetQty <= @n_packqty
            BEGIN
            	 UPDATE #PICKDETAIL_WIP WITH (ROWLOCK)
            	 SET CaseId = @c_labelno
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
               @b_success OUTPUT,
               @n_err OUTPUT,
               @c_errmsg OUTPUT
               
               IF NOT @b_success = 1
               BEGIN
               	  SELECT @n_continue = 3
               END

            	 INSERT #PICKDETAIL_WIP
                      (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                       Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
                       DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                       ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                       WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, Taskdetailkey, TaskManagerReasonkey, Notes, WIP_Refno, Channel_ID)
               SELECT @c_newpickdetailkey, '', PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                      Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_splitqty ELSE UOMQty END , @n_splitqty, QtyMoved, Status,
                      DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                      WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo, Taskdetailkey, TaskManagerReasonkey, Notes, WIP_Refno, Channel_ID
               FROM #PickDetail_WIP (NOLOCK)
               WHERE PickDetailKey = @c_PickDetailKey
                  
               UPDATE #PICKDETAIL_WIP 
            	 SET CaseId = @c_labelno,
            	     Qty = @n_packqty,
		         	     UOMQTY = CASE UOM WHEN '6' THEN @n_packqty ELSE UOMQty END
            	 WHERE PickDetailKey = @c_PickDetailKey
         
               SELECT @n_packqty = 0
            END
            FETCH NEXT FROM CUR_PICKDET_UPDATE INTO @c_PickDetailKey, @n_PickdetQty
         END
         CLOSE CUR_PICKDET_UPDATE
         DEALLOCATE CUR_PICKDET_UPDATE   
   
         FETCH NEXT FROM CUR_LABELUPD INTO @c_Orderkey, @c_Storerkey, @c_Sku, @c_UOM, @n_PackQty, @c_LabelNo         
      END         
      CLOSE CUR_LABELUPD
      DEALLOCATE CUR_LABELUPD
   END
   
   -----Update pickdetail_WIP work in progress staging table back to pickdetail    
   IF @n_continue IN(1,2)
   BEGIN
      EXEC isp_CreatePickdetail_WIP
            @c_Loadkey               = ''
           ,@c_Wavekey               = @c_wavekey
           ,@c_WIP_RefNo             = @c_SourceType
           ,@c_PickCondition_SQL     = ''
           ,@c_Action                = 'U'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
           ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
           ,@b_Success               = @b_Success OUTPUT
           ,@n_Err                   = @n_Err     OUTPUT
           ,@c_ErrMsg                = @c_ErrMsg  OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END
   END    

QUIT_SP:

   IF OBJECT_ID('tempdb..#PICKDETAIL_WIP') IS NOT NULL
      DROP TABLE #PICKDETAIL_WIP
   IF OBJECT_ID('tempdb..#SKUDIM') IS NOT NULL
      DROP TABLE #SKUDIM
   IF OBJECT_ID('tempdb..#ORDERSKU') IS NOT NULL
      DROP TABLE #ORDERSKU
   IF OBJECT_ID('tempdb..#CARTONIZATION') IS NOT NULL
      DROP TABLE #CARTONIZATION
   IF OBJECT_ID('tempdb..#OptimizeItemToPack') IS NOT NULL
      DROP TABLE #OptimizeItemToPack
   IF OBJECT_ID('tempdb..#OptimizeResult') IS NOT NULL
      DROP TABLE #OptimizeResult
   IF OBJECT_ID('tempdb..#CARTON') IS NOT NULL
      DROP TABLE #CARTON
   IF OBJECT_ID('tempdb..#CARTONDETAIL') IS NOT NULL
         DROP TABLE #CARTONDETAIL

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRLWAV58_PACK'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO