SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* SP: ispWAVPK15                                                       */
/* Creation Date: 28-OCT-2021                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-18203 - HK AEO Exceed Generate Pack by Picked           */
/*        : Copy & Modified from ispWAVPK03                             */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: WAVE storerconfig: WAVGENPACKFROMPICKED_SP                */
/*                                                                      */
/* RDTMsg :                                                             */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver      Purposes                               */
/* 28-Oct-2021 NJOW     1.0      DEVOPS combine script                  */
/************************************************************************/
CREATE PROC [dbo].[ispWAVPK15](
    @c_WaveKey       NVARCHAR(20)
   ,@b_Success       INT            OUTPUT
   ,@n_err           INT            OUTPUT
   ,@c_ErrMsg        NVARCHAR(250)  OUTPUT      
)
AS
BEGIN

   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   declare @n_Debug                 INT

   DECLARE    @c_Orderkey           VARCHAR(15)
            , @CartonizationRuleKey NVARCHAR(20)
            , @c_PickSlipno         NVARCHAR(10)
            , @cLabelNo             NVARCHAR(20)
            , @c_PickDetailKey      NVARCHAR(18)
            , @c_DropID             NVARCHAR(20)
            , @c_NewPickDetailKey   NVARCHAR(18)
            , @c_StorerKey          NVARCHAR(15)
            , @c_BillToKey          NVARCHAR(15)
            , @c_CartonizationGroup NVARCHAR(10)
            , @c_CartonGroup        NVARCHAR(10)
            , @c_CartonType         NVARCHAR(10)   
            , @n_StartTCnt          INT
            , @CartonNo             INT                        
            , @n_continue           INT
            , @SKU                  NVARCHAR(20)
            , @Qty                  INT
            , @PickDetailQty        INT
            , @CntCount             INT
            , @c_ID                 NVARCHAR(18)
            , @n_LastCartonNo       INT 
            , @c_sts                NVARCHAR(1) 
            , @c_LocationType       NVARCHAR(10) 
            , @n_LLIQty             INT  
            , @n_PDQty              INT  
            , @c_UOM                NVARCHAR(10) 

   DECLARE  @CurrUseSequence        INT,
            @Cube                   FLOAT,
            @MaxWeight              FLOAT,
            @MaxCount               INT,
            @CartonLength           FLOAT,
            @CartonHeight           FLOAT,
            @CartonWidth            FLOAT,
            @FillTolerance          INT,
            @CurrWeight             FLOAT,
            @CurrCube               FLOAT,
            @CurrCount              INT
                                    
   DECLARE  @SKULength              FLOAT,
            @SKUCUBE                FLOAT,
            @SKUWeight              FLOAT,
            @SKUHeight              FLOAT, 
            @SKUWidth               FLOAT,
            @SKUBusr7               NVARCHAR(20),            
            @OrderGroup             NVARCHAR(20),
            @OrderRoute             NVARCHAR(10),
            @c_UDF02                NVARCHAR(30)
            
   DECLARE @n_PreCTNCapacityTol     DECIMAL(10,2)
         , @c_PreCTNCapacityTol     NVARCHAR(30)
         , @n_CapacityLimit         FLOAT
         , @c_Facility              NVARCHAR(5)    
         , @c_ItemGroup1            NVARCHAR(30)
         , @c_ItemGroup2            NVARCHAR(30)
         , @c_ItemGroup3            NVARCHAR(75)
         , @c_ItemGroup4            NVARCHAR(30)       
         , @c_MinPickSlipNo         NVARCHAR(10)
         , @c_MaxCaseID             NVARCHAR(20)
         , @n_MinStdCube            FLOAT
         , @n_MinCTCube             FLOAT
                                    
   DECLARE @n_TotalSkuQty           INT           
         , @n_TotalSkuCube          FLOAT         
         , @n_TotalSkuCapacityLimit FLOAT   
         , @n_SkuCapacityLimit      FLOAT   
         , @c_ItemGroup1_Prev       NVARCHAR(30)  
         , @c_ItemGroup2_Prev       NVARCHAR(30)  
         , @c_ItemGroup3_Prev       NVARCHAR(75)  
         , @c_ItemGroup4_Prev       NVARCHAR(30)  
         , @n_PickQty               INT           
         , @n_PackQty               INT           
         , @n_SplitQty              INT           
   
   SELECT @b_success = 1 --Preset to success
   SET @n_Debug = 0
   SET @n_StartTCnt=@@TRANCOUNT
   SET @n_continue = 1
   
   --Get CartonGroup
   IF @n_continue IN(1,2)
   BEGIN
   	  SELECT TOP 1 @c_Storerkey = O.Storerkey
   	  FROM WAVEDETAIL WD (NOLOCK)
   	  JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
   	  WHERE WD.Wavekey = @c_Wavekey
   	  
   	  SELECT TOP 1 @c_CartonizationGroup = CL.Short
   	  FROM CODELKUP CL (NOLOCK)
   	  WHERE CL.Listname = 'PRECTNPARM'
   	  AND CL.Storerkey = @c_Storerkey
   	    
   	  IF ISNULL(@c_CartonizationGroup,'') = ''
   	  BEGIN
   	     SELECT @c_CartonizationGroup = CartonGroup
   	     FROM STORER(NOLOCK)
   	     WHERE Storerkey = @c_Storerkey
   	  END   	  
   END
                
   --Validation
   IF @n_continue IN(1,2)
   BEGIN
      SELECT @c_MinPickSlipNo = ISNULL(MIN(PD.PickSlipNo), '')
            ,@c_MaxCaseID     = ISNULL(MAX(PD.CaseID), '')
            ,@n_MinStdCube    = ISNULL(Min(SKU.StdCube), 0.00) 
            ,@n_MinCTCube     = ISNULL(MIN(CT.Cube), 0.00)
      FROM WAVE        WH WITH (NOLOCK)      
      JOIN WaveDetail  WD WITH (NOLOCK) ON WH.Wavekey = WD.WaveKey
      JOIN ORDERS      OH WITH (NOLOCK) ON WD.OrderKey= OH.OrderKey
      JOIN PICKDETAIL  PD WITH (NOLOCK) ON OH.OrderKey= PD.OrderKey
      LEFT JOIN CARTONIZATION CT WITH (NOLOCK) ON CT.CartonizationGroup = @c_CartonizationGroup  and CT.usesequence = '1'
      JOIN SKU            SKU    WITH (NOLOCK) ON SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU
      WHERE WH.WaveKey = @c_WaveKey
      
      --if pickdetail.pickslipno is blank or null, prompt error message  
      IF @c_MinPickSlipNo = ''
      BEGIN
         SET @b_Success = 0
         SET @n_continue = 3
         SET @n_err = 60002
         SET @c_ErrMsg = 'Pick Slip No are blank, cannot run pre-cartonization'
         GOTO QUIT_SP        
      END
      
      --If detecting one item has no value in sku.stdcube, prompt error message 
      IF @n_MinStdCube = 0.00
      BEGIN
         SET @b_Success = 0
         SET @n_continue = 3
         SET @n_err = 60003
         SET @c_ErrMsg = 'one of the SKu StdCude No are blank, cannot run pre-cartonization'
         GOTO QUIT_SP        
      END
      
      --If cartonization.cube is not maintained ,  prompt error message 
      IF @n_MinCTCube <= 0.00
      BEGIN
         SET @b_Success = 0
         SET @n_continue = 3
         SET @n_err = 60004
         SET @c_ErrMsg = 'cartonization.cube is not maintained'
         GOTO QUIT_SP 
      END
   END
   
   --Create temp tables
   IF @n_continue IN(1,2)
   BEGIN
      IF OBJECT_ID('tempdb..#PICK_PIECE','u') IS NOT NULL
      DROP TABLE #PICK_PIECE;
      
      CREATE TABLE #PICK_PIECE 
            ( PickDetailKey   NVARCHAR(10)   NOT NULL PRIMARY KEY
            , PickSlipNo      NVARCHAR(10)   NULL
            , Storerkey       NVARCHAR(15)   NULL
            , SKU             NVARCHAR(20)   NULL
            , Qty             INT            NULL  
            , ItemGroup1      NVARCHAR(30)   NULL  
            , ItemGroup2      NVARCHAR(30)   NULL
            , ItemGroup3      NVARCHAR(75)   NULL
            , ItemGroup4      NVARCHAR(30)   NULL      
            , ItemStyle       NVARCHAR(20)   NULL
            , ItemBUSR1       NVARCHAR(60)   NULL
            , ItemColor       NVARCHAR(10)   NULL
            , ItemSize        NVARCHAR(10)   NULL
            , ItemMeasure     NVARCHAR(5)    NULL
            , BillToKey       NVARCHAR(15)   NULL
            , Susr5           NVARCHAR(18)   NULL
            )
      
      IF OBJECT_ID('tempdb..#OpenCarton','u') IS NOT NULL
      DROP TABLE #OpenCarton;
      
      -- Store Open Carton 
      CREATE TABLE #OpenCarton (
            SeqNo       INT            NULL,  
            OrderKey    NVARCHAR(20)   NULL,                  
            PickSlipNo  NVARCHAR(10)   NULL,
            CartonNo    INT            NOT NULL PRIMARY KEY,         
            CartonType  NVARCHAR(20)   NULL,
            CartonSeq   NVARCHAR(5)    NULL, 
            CartonGroup NVARCHAR(20)   NULL,
            CurrWeight  Float          NULL DEFAULT(0.00),
            CurrCube    Float          NULL DEFAULT(0.00),
            CurrCount   INT            NULL DEFAULT(0),
            Sts         VARCHAR(1)     NULL DEFAULT('0')-- 0 open, 9 closed
         ,  ItemGroup1  NVARCHAR(30)   NULL 
         ,  ItemGroup2  NVARCHAR(30)   NULL
         ,  ItemGroup3  NVARCHAR(75)   NULL
         ,  ItemGroup4  NVARCHAR(30)   NULL 
         ,  ID          NVARCHAR(18)   NULL   
         ,  FullCase    NVARCHAR(5)    NULL 
      )
      
      IF OBJECT_ID('tempdb..#OpenCartonDetail','u') IS NOT NULL
      DROP TABLE #OpenCartonDetail;
      
      -- Store Open Carton 
      CREATE TABLE #OpenCartonDetail (  
            SeqNo             INT   IDENTITY(1,1) PRIMARY KEY,
            CartonNo          INT   NULL,
            PickDetailKey     NVARCHAR(18)   NULL,
            LabelNo           NVARCHAR(20)   NULL,
            SKU               NVARCHAR(20)   NULL,
            PackQty           INT            NULL,
            Cube              FLOAT          NULL, 
            Weight            FLOAT          NULL
      )
      
      IF OBJECT_ID('tempdb..#PickDetail','u') IS NOT NULL
            DROP TABLE #PickDetail;
      
      -- Store PickDetail by OrderKey
      CREATE TABLE #PickDetail (
            PickDetailKey  NVARCHAR(18)   NOT NULL  PRIMARY KEY,
            PickSlipNo     NVARCHAR(10)   NULL,
            OrderKey       NVARCHAR(20)   NULL, 
            OrderGroup     NVARCHAR(20)   NULL,    
            Route          NVARCHAR(10)   NULL,
            BillToKey      NVARCHAR(15)   NULL,
            SKU            NVARCHAR(20)   NULL,
            Qty            INT            NULL,
            PackQty        INT            NULL,
            Storerkey      NVARCHAR(30)   NULL,
            UOM            NVARCHAR(10)   NULL,
            Sts            CHAR(1)        NULL,
            LabelNo        NVARCHAR(20)   NULL,
            DropID         NVARCHAR(20)   NULL,
            CartonGroup    NVARCHAR(10)   NULL,
            CartonType     NVARCHAR(10)   NULL,
            ItemGroup1     NVARCHAR(30)   NULL,
            TariffLookup   CHAR(1) DEFAULT ('N'),
            ID             NVARCHAR(18)   NULL,  
            B_Country      NVARCHAR(30)   NULL,
            Lot            NVARCHAR(10)   NULL        
      )
   END
   
   --Prepare reference records
   IF @n_continue IN(1,2)
   BEGIN
      INSERT #PickDetail (PickDetailKey, OrderKey, OrderGroup, Route,  BillToKey
                        , SKU, Qty, PackQty, Storerkey, UOM, Sts, DropID, PickSlipNo
                        , ItemGroup1, TariffLookup, ID, B_Country, Lot)
      SELECT PD.PickDetailKey, PD.OrderKey, OH.OrderGroup, OH.Route, ISNULL(RTRIM(OH.BillToKey),'')
                        ,PD.Sku, PD.Qty, 0, PD.Storerkey, PD.UOM, '0', PD.DropID, PD.PickSlipNo
                        , '', 'N', 
                        PD.ID,
                        OH.B_Country,
                        PD.Lot 
      FROM WAVE        WH WITH (NOLOCK)      
      JOIN WaveDetail  WD WITH (NOLOCK) ON WH.Wavekey = WD.WaveKey
      JOIN ORDERS      OH WITH (NOLOCK) ON WD.OrderKey= OH.OrderKey
      JOIN PickDetail  PD WITH (NOLOCK) ON OH.OrderKey= PD.OrderKey 
      WHERE WH.WaveKey = @c_WaveKey
      AND   PD.UOM NOT IN ('6', '7')
      AND  (PD.CaseID = '' OR PD.CaseID IS NULL)  
      UNION
      SELECT PD.PickDetailKey, PD.OrderKey, OH.OrderGroup, OH.Route, ISNULL(RTRIM(OH.BillToKey),'')
            , PD.Sku, PD.Qty, 0, PD.Storerkey, PD.UOM, '0', PD.DropID, PD.PickSlipNo
            ,CASE WHEN CLAI008.Code IS NOT NULL THEN LA.Lottable01 ELSE '' END 
            , CASE WHEN CL2.Code IS NOT NULL THEN 'Y' ELSE 'N' END   
            , PD.ID 
            , OH.B_Country 
            , PD.Lot
      FROM WAVE         WH WITH (NOLOCK)      
      JOIN WaveDetail   WD WITH (NOLOCK) ON WH.Wavekey = WD.WaveKey
      JOIN ORDERS       OH WITH (NOLOCK) ON WD.OrderKey= OH.OrderKey 
      JOIN PickDetail   PD WITH (NOLOCK) ON OH.OrderKey= PD.OrderKey 
      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON PD.Lot = LA.Lot
      LEFT JOIN CODELKUP CLAI008 WITH (NOLOCK) ON OH.BillToKey = CLAI008.Code AND CLAI008.Listname = 'PVHCONSO' AND CLAI008.UDF02 = '1' 
      LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON OH.BillToKey = CL2.Code AND CL2.ListName = 'PVHCONSO' AND CL2.UDF01 = '1'                             
      WHERE WD.WaveKey = @c_WaveKey
      AND   PD.UOM     IN ('6', '7') 
      AND  (PD.CaseID = '' OR PD.CaseID IS NULL)  
      ORDER BY PD.OrderKey, PD.UOM
      
      IF @@ROWCOUNT = 0
      BEGIN
         SET @b_Success = 0
         SET @n_continue = 3
         SET @n_err = 60006
         SET @c_ErrMsg = 'No PickDetail line'
         GOTO QUIT_SP   
      END   

      --Check carton Cube size must bigger than SKu.StdCube size 
      SELECT  TOP 1 @SKU = SKU.SKU
      FROM #PickDetail PD WITH (NOLOCK)
      JOIN CodelKup WITH (NOLOCK) ON CodelKup.ListName = 'ORDERGROUP' 
                                  AND CodelKup.StorerKey = PD.StorerKey 
                                  AND CodelKup.Code = PD.OrderGroup
      JOIN Cartonization WITH (NOLOCK) ON Cartonization.Cartonizationgroup = @c_CartonizationGroup
                                       AND Cartonization.UseSequence = 1         
      JOIN SKU WITH (NOLOCK) ON SKU.SKU = PD.SKU 
      WHERE Cartonization.Cube < SKU.STDCube
      
      if isnull(@SKU, '')<>''
      BEGIN
         SET @b_Success = 0
         SET @n_continue = 3  
         SET @n_err = 60007
         SET @c_ErrMsg = 'SKU:'+ @SKU + ' sku.stdcube > cartonization.cube'
         GOTO QUIT_SP
      END  
   END
    
   -- Handle The Full UCC first, PickDetail.UOM = 2    
   IF @n_continue IN(1,2)
   BEGIN
      DECLARE CUR_OrderList CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DropID,  SKU, Storerkey, SUM(Qty), PickSlipNo, ID 
               ,BillToKey 
         FROM #PickDetail 
         WHERE UOM = 2 and Sts = '0' -- Full UCC only      
         GROUP BY DropID,  SKU, Storerkey, PickSlipNo, ID, BillToKey 
         Order by Pickslipno, SKU
                       
      OPEN CUR_OrderList  
      FETCH NEXT FROM CUR_OrderList INTO @c_DropID, @SKU, @c_StorerKey, @Qty, @c_PickSlipno, @c_ID  
                                       , @c_BillToKey                             
         
      WHILE (@@FETCH_STATUS <> -1)     
      BEGIN   
         --IF Order consist by multiple Ordergroup. report error.
         IF (select Count(OrderGroup)
         FROM (
               select Distinct OrderGroup from #PickDetail WITH (NOLOCK)
               where PickSlipNo = @c_PickSlipno
           ) a) >1   
         BEGIN
            SET @b_Success = 0
            SET @n_continue = 3
            SET @n_err = 60008
            SET @c_ErrMsg = 'Order not allowed Consist Multiple order group.'
            GOTO QUIT_SP
         END
      
         --Reset Variable
         SET @OrderGroup = ''
         SET @OrderRoute = ''         
         SET @cLabelNo = ''
         SET @c_UDF02 =''
         SET @c_CartonGroup = @c_CartonizationGroup
               
         /*SELECT TOP 1 @c_CartonGroup = Storer.CartonGroup
         FROM Storer WITH (NOLOCK) 
         WHERE Storer.StorerKey = @c_StorerKey
         AND Storer.Type ='1'*/
         
         SELECT @c_UDF02 = ISNULL(Short,'')
         FROM CODELKUP (NOLOCK) 
         WHERE Code = @c_BillTokey 
         AND Listname = 'PVHCONSO' 
               
         IF ISNULL(@c_UDF02,'') = ''
         BEGIN 
            SELECT TOP 1 @OrderGroup = #PickDetail.OrderGroup
                       , @OrderRoute = #PickDetail.Route
                       , @c_UDF02 = CodelKup.UDF02
            FROM #PickDetail WITH (NOLOCK)
            JOIN CodelKup WITH (NOLOCK) ON CodelKup.ListName = 'ORDERGROUP' AND CodelKup.StorerKey = @c_StorerKey AND CodelKup.Code = #PickDetail.OrderGroup
            WHERE #PickDetail.ID = @c_ID 
            AND #PickDetail.PickSlipNo = @c_PickSlipno
            AND #PickDetail.Storerkey = @c_Storerkey 
            AND #PickDetail.Sku = @Sku 
         END
      
         -- Create packheader if not exists      
         IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipno)
         BEGIN      
            --Consolidate consolidate  pick & pack 
            IF @c_UDF02 = 'C'
            BEGIN
               INSERT INTO dbo.PackHeader
                  (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, CartonGroup, Status
                  ,CtnTyp2, CtnTyp3, CtnTyp4, CtnTyp5, TotCtnWeight, ConsoOrderKey, ManifestPrinted, PackStatus
                  , CtnCnt2, CtnCnt3, CtnCnt4, CtnCnt5   
                  ,TaskBatchNo, ComputerName )
                  SELECT DISTINCT '', '', '', b.LoadKey, null, a.StorerKey, a.PickSlipNo, @c_CartonGroup, 0
                  ,'','','','', 0, '', 0, 0
                  ,0,0,0,0
                  ,'',''
                  FROM PickDetail a WITH (NOLOCK)
                  JOIN LoadPlanDetail b (NOLOCK) on b.orderkey = a.orderkey
                  JOIN Orders O WITH (NOLOCK) ON O.Orderkey = a.Orderkey
                  WHERE a.ID = @c_ID 
                  AND a.PickSlipNo = @c_PickSlipno 
                  AND a.Storerkey = @c_Storerkey 
                  AND a.Sku = @Sku 
                  --WHERE PickDetailKey = @c_PickDetailKey
               END
            ELSE IF @c_UDF02 = 'D' --discrete pick & pack 
            BEGIN 
               INSERT INTO dbo.PackHeader
                  (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, CartonGroup, Status
                  ,CtnTyp2, CtnTyp3, CtnTyp4, CtnTyp5, TotCtnWeight, ConsoOrderKey, ManifestPrinted, PackStatus
                  , CtnCnt2, CtnCnt3, CtnCnt4, CtnCnt5 
                  ,TaskBatchNo, ComputerName)
                  SELECT distinct b.Route,  a.Orderkey, b.ExternOrderkey, b.Loadkey, b.ExternOrderkey, a.Storerkey, a.PickSlipNo, @c_CartonGroup, 0
                  ,'','','','', 0, '', 0, 0
                  ,0,0,0,0
                  ,'',''
                  FROM PickDetail a WITH (NOLOCK)
                  JOIN LoadPlanDetail b (NOLOCK) on b.orderkey = a.orderkey
                  JOIN Orders O WITH (NOLOCK) ON O.Orderkey = a.Orderkey
                  WHERE a.ID = @c_ID 
                  AND a.PickSlipNo = @c_PickSlipno 
                  AND a.Storerkey = @c_Storerkey 
                  AND a.Sku = @Sku 
            END
            ELSE
            BEGIN
               SET @b_Success = 0
               SET @n_continue = 3
               SET @n_err = 60009
               SET @c_ErrMsg = 'Invalid Order Group Setup. quit SP'
               GOTO QUIT_SP
            END
         
            IF @@Error <>0
            BEGIN
               SET @b_Success = 0
               SET @n_continue = 3
               SET @n_err = 60010
               SET @c_ErrMsg = 'Faled to Create PackHeader'
               GOTO QUIT_SP
            END
         END 
          
         --Get SKU Size info
         SELECT @SKULength = SKU.Length,
               @SKUHeight = SKU.Height,
               @SKUWidth = SKU.Width,
               @SKUCUBE = SKU.STDCube,
               @SKUWeight = SKU.STDGrossWGT         
         FROM SKU SKU(NOLOCK)                   
         WHERE SKU.SKU = @SKU AND SKU.StorerKey = @c_StorerKey
        
      
      --Check Every Carton to look for Suitable Box
      --WHILE 1=1 -- @CurrUseSequence <= ( SELECT min(UseSequence) FROM Cartonization (NOLOCK) WHERE Cartonizationgroup = @c_CartonGroup )
      --BEGIN
         --Reset To Default value
         SET @Cube            = ''
         SET @MaxWeight       = ''
         SET @MaxCount        = ''
         SET @CartonLength    = ''
         SET @CartonHeight    = ''
         SET @CartonWidth     = ''
         SET @FillTolerance   = ''
         SET @c_CartonType    = ''
      
         SELECT top 1  @Cube    = Cube,
                 @MaxWeight     = MaxWeight,    
                 @MaxCount      = MaxCount,   
                 @CartonLength  = CartonLength, 
                 @CartonHeight  = CartonHeight,
                 @CartonWidth   = CartonWidth, 
                 @c_CartonType  = CartonType
         FROM Cartonization (NOLOCK) 
         WHERE Cartonizationgroup = @c_CartonGroup AND (@SKUCUBE * @Qty)< Cube
         ORDER By Cube --UseSequence = @CurrUseSequence 
         
         --if got no suitable carton size, take the biggest one
         IF @Cube =''
         BEGIN
            SELECT top 1  @Cube    = Cube,
                 @MaxWeight     = MaxWeight,    
                 @MaxCount      = MaxCount,   
                 @CartonLength  = CartonLength, 
                 @CartonHeight  = CartonHeight,
                 @CartonWidth   = CartonWidth, 
                 @c_CartonType  = CartonType
            FROM Cartonization (NOLOCK) 
            WHERE Cartonizationgroup = @c_CartonGroup 
            ORDER By Cube DESC
         END
        
         IF @n_Debug =2
         BEGIN
            SELECT @Cube 'CartonCube', @MaxWeight ,@MaxCount ,@CartonLength 'CartonLength', @CartonHeight 'CartonHeight', @CartonWidth 'CartonWidth', @FillTolerance 'FillTolerance', @c_CartonType 'CartonType  '
            SELECT @SKU 'SKU', @SKUCube 'SKUCUBE', @SKULength 'SKULength', @SKUHeight 'SKUHeight', @SKUWeight 'SKUWeight'
         END        
                
         IF (@Cube <>'' and @MaxWeight <>'' and @MaxCount <> '' and @CartonLength <>'' and @CartonHeight <> '' and @CartonWidth <>'' and @c_CartonType <>'')
         BEGIN
            --Get New CartonKey
            EXECUTE nspg_getkey
                  'CartonKey'
                  , 10
                  , @CartonNo OUTPUT
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
         
            IF NOT @b_success = 1
               BEGIN
               SET @n_continue = 3
               SET @n_err = 60011
               SET @c_errmsg = 'Cartonization: ' + RTRIM(@c_errmsg)
               GOTO QUIT_SP
            END
                           
            --Insert 
            INSERT #OpenCartonDetail(CartonNo, Pickdetailkey, LabelNo, SKU, PackQty, 
                     Cube, 
                     Weight)
            SELECT @CartonNo, PickDetailKey, '', SKU, Qty, 
                     @SKUCUBE,@SKUWeight 
            FROM #PickDetail 
            WHERE ID = @c_ID  
            AND UOM = 2 AND SKU =@SKU
      
            --Size Can feed, put SKU into the box
            INSERT #OpenCarton (OrderKey, PickSlipNo, CartonNo, CartonType, CartonGroup,
                           CurrWeight, 
                           CurrCube, 
                           CurrCount,
                           Sts,
                           ID, 
                           FullCase)  
            SELECt @c_Orderkey, @c_PickSlipno, @CartonNo, @c_CartonType, @c_CartonGroup,
            SUM(@SKUWeight * @Qty),   
            SUM(@SKUCUBE * @Qty) ,   
            SUM(@Qty),
            '9', --Close Carton.
            @c_ID, 
            'Y' 
         END
         ELSE          
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60012
            SET @c_ErrMsg = 'No Carton to use'                              
         END
      
NEXT_CartonType:
      
         --Set Complete the this line of record
         UPDATE #PickDetail
         SET  Sts = '9'
         WHERE ID = @c_ID AND UOM= '2'  
         AND PickSlipNo = @c_PickSlipno 
         AND Storerkey = @c_Storerkey
         AND Sku = @Sku 
         
         DELETE CartonList 
         WHERE CartonKey IN ( SELECT CartonListDetail.CartonKey 
                              FROM CartonListDetail WITH (NOLOCK) 
                              JOIN #PickDetail ON CartonListDetail.Pickdetailkey = #PickDetail.Pickdetailkey  
                              WHERE #PickDetail.ID = @c_ID  
                              AND #PickDetail.PickSlipNo = @c_PickSlipno 
                              AND #PickDetail.Storerkey = @c_Storerkey 
                              AND #PickDetail.Sku = @Sku 
                              )
         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 60013   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update CartonList Table Failed. (ispWAVPK15)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END
      
         DELETE CartonListDetail 
         WHERE Pickdetailkey IN (SELECT Pickdetailkey FROM #PickDetail WHERE ID = @c_ID) 
         --WHERE PickDetailKey = @c_PickDetailKey
         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 60014   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update CartonList Table Failed. (ispWAVPK15)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END
               
         FETCH NEXT FROM CUR_OrderList INTO  @c_DropID, @SKU, @c_StorerKey, @Qty, @c_PickSlipno, @c_ID 
                                          , @c_BillToKey     
      END --end of while
      CLOSE CUR_OrderList
      DEALLOCATE CUR_OrderList
      
      --select * from #PickDetail
      --select * from #OpenCarton
      --select * from #OpenCartonDetail
      --return
      --set @b_Success =0
   END
   
   --===========================================================================================================
   --Cartonization for loose qty
   IF @n_continue IN(1,2)
   BEGIN
      SET @c_Facility = ''
      SELECT TOP 1 @c_Facility = OH.Facility
      FROM WAVE         WH WITH (NOLOCK)
      JOIN WAVEDETAIL   WD WITH (NOLOCK) ON (WH.Wavekey = WD.Wavekey)
      JOIN ORDERS       OH WITH (NOLOCK) ON (WD.Orderkey= OH.Orderkey) 
      WHERE WH.Wavekey = @c_Wavekey
      
      SET @n_PreCTNCapacityTol = 95.00
      
      INSERT INTO #PICK_PIECE 
            ( PickDetailKey
            , PickSlipNo
            , Storerkey
            , SKU
            , Qty
            , ItemGroup1
            , ItemGroup2 
            , ItemGroup3 
            , ItemGroup4  
            , ItemStyle  
            , ItemBUSR1  
            , ItemColor  
            , ItemSize   
            , ItemMeasure 
            , BillToKey
            , Susr5
            )
      SELECT a.PickDetailKey, a.PickSlipNo, a.Storerkey, a.SKU, a.Qty
            /*, a.ItemGroup1 
            , ItemGroup2 = CASE WHEN CL.Code IS NOT NULL      
                                THEN 'BRA' ELSE 'NON-BRA' END
            , ItemGroup3 = CASE WHEN CLAI008.Code IS NOT NULL                              
                                THEN ISNULL(RTRIM(b.Style),'') 
                                    +ISNULL(RTRIM(b.Busr1),'') 
                                    +ISNULL(RTRIM(b.Color),'')
                                    +ISNULL(RTRIM(b.Size),'')  
                                    +ISNULL(RTRIM(b.Measurement),'')
                                ELSE ''
                                END
            */
            ,'' as itemgroup1
            ,'' as itemgroup2                                
            ,'' as itemgroup3
            , ItemGroup4 = CASE --WHEN CLAI008.Code IS NULL THEN
                                --     ''
                                WHEN ISNULL(CLAI008.Long,'') IN ('RULES1','') THEN                            
                                     ISNULL(RTRIM(b.Busr9),'')
                                WHEN ISNULL(CLAI008.Long,'') IN ('RULES2') THEN
                                     ''
                                WHEN ISNULL(CLAI008.Long,'') IN ('RULES3','RULES5') THEN
                                     ISNULL(RTRIM(b.Susr3),'') 
                                    +ISNULL(RTRIM(b.Style),'')     
                                    +ISNULL(RTRIM(b.Color),'')                                                                        
                                WHEN ISNULL(CLAI008.Long,'') IN ('RULES4') THEN
                                     ISNULL(RTRIM(b.Sku),'') 
                                WHEN ISNULL(CLAI008.Long,'') IN ('RULES6') THEN                                     
                                     ISNULL(RTRIM(LA.Lottable01),'') + REPLACE(REPLACE(ISNULL(LTRIM(b.BUSR9),''), '-S', ''), '-B', '')
                                WHEN ISNULL(CLAI008.Long,'') IN ('RULES7') THEN
                                     ISNULL(RTRIM(b.Susr3),'')
                                    +ISNULL(RTRIM(b.Style),'') 
                                ELSE ''
                                END  
            , ItemStyle = b.Style
            , ItemBUSR1 = b.Busr1
            , ItemColor = b.Color
            , ItemSize  = CASE WHEN b.Size = 'XXS' THEN '01'
                               WHEN b.Size = 'XS'  THEN '02'
                               WHEN b.Size = 'S'   THEN '03'
                               WHEN b.Size = 'M'   THEN '04'
                               WHEN b.Size = 'L'   THEN '05'
                               WHEN b.Size = 'XL'  THEN '06'
                               WHEN b.Size = 'XXL' THEN '07'
                               ELSE b.Size END
            , ItemMeasure = b.Measurement
            , BillToKey = a.BillToKey
            , Susr5 = b.Susr5
      FROM #PickDetail a (NOLOCK)
      JOIN SKU b (NOLOCK) ON b.SKU = a.SKU AND b.StorerKey = a.StorerKey
      JOIN Lotattribute LA (NOLOCK) ON a.Lot = LA.Lot
      LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'PVHBRA')
                                          AND(CL.Storerkey= b.Storerkey)
                                          AND(CL.Code = b.Tariffkey)
                                          AND(a.TariffLookup = 'Y')
      OUTER APPLY (SELECT TOP 1 CL2.Long, CL2.Code FROM CODELKUP CL2 (NOLOCK) WHERE a.BillToKey = CL2.Code AND CL2.ListName = 'PVHCONSO') AS CLAI008                               
      WHERE a.UOM in ('6','7') and a.Sts = '0' -- Full UCC only
      
      SET @c_PickDetailKey = '' 
      SET @CartonNo = ''
      
      SET @CurrCube = 0                             
      
      SET @c_ItemGroup1_Prev = ''                   
      SET @c_ItemGroup2_Prev = ''                   
      SET @c_ItemGroup3_Prev = ''                   
      SET @c_ItemGroup4_Prev = ''                   
      
      --Start handle UOM in 6, 7
      --Prepare the possible grouping line
      DECLARE CUR_OrderList2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      
         SELECT a.SKU, a.Storerkey, Sum(a.Qty) 'Qty', a.PickSlipNo, a.PickDetailKey
              , a.ItemGroup1, a.ItemGroup2, a.ItemGroup3, a.ItemGroup4, a.BillToKey 
         FROM #PICK_PIECE a (NOLOCK)
         GROUP By a.PickDetailKey, a.PickSlipNo, a.Storerkey, a.SKU
            , a.Qty     
            , a.ItemGroup2, a.ItemGroup3,  a.ItemGroup1
            , a.ItemStyle,  a.ItemBusr1,   a.ItemColor
            , a.ItemSize,   a.ItemMeasure, a.BillToKey, a.ItemGroup4, a.Susr5
         Order by a.ItemGroup4, a.PickSlipNo, a.Susr5, a.ItemStyle, a.ItemColor, a.ItemSize
         --Order by a.PickSlipNo, a.ItemGroup2
         --    , a.ItemStyle, a.ItemBusr1, a.ItemColor
         --    , a.ItemSize, a.ItemMeasure, a.ItemGroup3, a.ItemGroup1, a.ItemGroup4  
                 
      OPEN CUR_OrderList2  
      FETCH NEXT FROM CUR_OrderList2 INTO @SKU, @c_StorerKey, @Qty, @c_PickSlipNo, @c_PickDetailKey
                                        , @c_ItemGroup1, @c_ItemGroup2, @c_ItemGroup3, @c_ItemGroup4, @c_BillToKey
         
      WHILE (@@FETCH_STATUS <> -1)     
      BEGIN   
            --Reset Variable
         SET @OrderGroup =''
         SET @OrderRoute = ''
         SET @c_UDF02 = ''
         SET @c_CartonGroup = @c_CartonizationGroup
      
         /*
         SELECT TOP 1 @c_CartonGroup = Storer.CartonGroup
         FROM Storer WITH (NOLOCK) 
         WHERE Storer.StorerKey = @c_StorerKey
         AND Storer.Type ='1'
         */
         
         SELECT @c_UDF02 = ISNULL(Short,'')
         FROM CODELKUP (NOLOCK) 
         WHERE Code = @c_BillTokey 
         AND Listname = 'PVHCONSO' 
               
         IF ISNULL(@c_UDF02,'') = ''      
         BEGIN 
            SELECT TOP 1 @OrderGroup = OrderGroup
                       , @OrderRoute = Route
                       , @c_UDF02 = CodelKup.UDF02
            FROM #PickDetail WITH (NOLOCK)
            JOIN CodelKup WITH (NOLOCK) ON CodelKup.ListName = 'ORDERGROUP' 
                                        AND CodelKup.StorerKey = @c_StorerKey 
                                        AND CodelKup.Code = OrderGroup
            where PickSlipNo = @c_PickSlipno
         END
      
         --Reset To Default value
         SET @Cube            = ''
         SET @MaxWeight       = ''
         SET @MaxCount        = ''
         SET @CartonLength    = ''
         SET @CartonHeight    = ''
         SET @CartonWidth     = ''
         SET @FillTolerance = ''
         SET @c_CartonType    = ''
                     
         SELECT TOP 1 @Cube          = Cube,
                     @MaxWeight     = MaxWeight,    
                     @MaxCount      = MaxCount,   
                     @CartonLength  = CartonLength, 
                     @CartonHeight  = CartonHeight,
                     @CartonWidth   = CartonWidth, 
                     @c_CartonType  = CartonType
         FROM Cartonization (NOLOCK) 
         WHERE Cartonizationgroup = @c_CartonGroup AND UseSequence = '1'
         ORDER BY Cube DESC
             
         -- Create packheader if not exists      
         IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipno)
         BEGIN      
            --Consolidate consolidate  pick & pack 
            IF @c_UDF02 = 'C'
            BEGIN
               INSERT INTO dbo.PackHeader
               (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, CartonGroup, Status
               ,CtnTyp2, CtnTyp3, CtnTyp4, CtnTyp5, TotCtnWeight, ConsoOrderKey, ManifestPrinted, PackStatus
               ,CtnCnt2, CtnCnt3, CtnCnt4, CtnCnt5 
               ,TaskBatchNo, ComputerName )
               SELECT DISTINCT '', '', '', b.LoadKey, null, a.StorerKey, a.PickSlipNo, @c_CartonGroup, 0
               ,'','','','', 0, '', 0, 0
               ,0,0,0,0
               ,'',''
               FROM PickDetail a WITH (NOLOCK)
               JOIN LoadPlanDetail b (NOLOCK) on b.orderkey = a.orderkey
               JOIN Orders O WITH (NOLOCK) ON O.Orderkey = a.Orderkey
               where PickSlipNo = @c_PickSlipno
            END 
            ELSe IF @c_UDF02 = 'D' --discrete pick & pack 
            BEGIN 
               INSERT INTO dbo.PackHeader
               (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, CartonGroup, Status
               ,CtnTyp2, CtnTyp3, CtnTyp4, CtnTyp5, TotCtnWeight, ConsoOrderKey, ManifestPrinted, PackStatus
               , CtnCnt2, CtnCnt3, CtnCnt4, CtnCnt5   
               ,TaskBatchNo, ComputerName)
               SELECT distinct b.Route,  a.Orderkey, b.ExternOrderkey, b.Loadkey, b.ExternOrderkey, a.Storerkey, a.PickSlipNo, @c_CartonGroup, 0
               ,'','','','', 0, '', 0, 0
               ,0,0,0,0
               ,'',''
               FROM PickDetail a WITH (NOLOCK)
               JOIN LoadPlanDetail b (NOLOCK) on b.orderkey = a.orderkey
               JOIN Orders O WITH (NOLOCK) ON O.Orderkey = a.Orderkey
               where PickSlipNo = @c_PickSlipno
            END
            ELSE
            BEGIN 
               SET @b_Success = 0
               SET @n_continue = 3
               SET @n_err = 60017
               SET @c_ErrMsg = 'Invalid Order Group Setup. quit SP'
               GOTO QUIT_SP
            END
         
            IF @@Error <>0
            BEGIN
               SET @b_Success = 0
               SET @n_continue = 3
               SET @n_err = 60018
               SET @c_ErrMsg = 'Failed to Create PackHeader'
               GOTO QUIT_SP
            END
         END  
      
         --Get SKU Size info
         SELECT @SKULength = SKU.Length,
               @SKUHeight = SKU.Height,
               @SKUWidth = SKU.Width,
               @SKUCUBE = SKU.STDCube,
               @SKUWeight = SKU.STDGrossWGT         
         FROM SKU SKU(NOLOCK)                   
         WHERE SKU.SKU = @SKU AND SKU.StorerKey = @c_StorerKey
      
         --base on grouping line get the related PickDetail
      
         SET @PickDetailQty = @Qty
         SET @CntCount = 1
      

         /*IF @c_ItemGroup3 <> ''
         BEGIN
            IF (@c_ItemGroup1 <> @c_ItemGroup1_Prev)
            OR (@c_ItemGroup2 <> @c_ItemGroup2_Prev)
            OR (@c_ItemGroup3 <> @c_ItemGroup3_Prev)
            OR (@c_ItemGroup4 <> @c_ItemGroup4_Prev) */
         IF 1 = 1
         BEGIN
            IF (@c_ItemGroup4 <> @c_ItemGroup4_Prev)
            BEGIN
               SET @n_TotalSkuQty = 0
               SET @n_TotalSkuCube = 0
               SET @n_TotalSkuCapacityLimit = 0
               SET @n_SkuCapacityLimit = 0
      
               SET @n_TotalSkuQty = 0
               SELECT @n_TotalSkuQty = ISNULL(SUM(a.qty),0)
               FROM #PICK_PIECE a (NOLOCK)
               WHERE a.PickSlipno = @c_PickSlipno 
               AND   a.StorerKey  = @c_StorerKey
               AND   a.ItemGroup1 = @c_ItemGroup1
               AND   a.ItemGroup2 = @c_ItemGroup2
               AND   a.ItemGroup3 = @c_ItemGroup3
               AND   a.ItemGroup4 = @c_ItemGroup4 
      
               SET @n_TotalSkuCube = @SKUCUBE * @n_TotalSkuQty
               SET @n_SkuCapacityLimit = CASE WHEN @n_PreCTNCapacityTol = 0 THEN 0
                                              ELSE ((@n_TotalSkuCube + @CurrCube) 
                                                 *  (@n_PreCTNCapacityTol / 100))
                                              END
               SET @n_TotalSkuCapacityLimit = CASE WHEN @n_PreCTNCapacityTol = 0 THEN 0
                                                   ELSE ( @n_TotalSkuCube 
                                                      *  (@n_PreCTNCapacityTol / 100))
                                                   END
      
               IF @n_Debug = 1
               BEGIN
                  SELECT @n_TotalSkuQty '@n_TotalSkuQty', @c_ItemGroup3 '@c_ItemGroup3'
                  SELECT @c_ItemGroup3 '@c_ItemGroup3'
                  , @n_TotalSkuCube + @CurrCube'@n_TotalSkuCube + @CurrCube'
                  , @CurrCube '@CurrCube'
                  , @n_TotalSkuCube '@n_TotalSkuCube'
                  , @n_SkuCapacityLimit '@n_SkuCapacityLimit'
                  , @n_TotalSkuCapacityLimit '@n_TotalSkuCapacityLimit'
                  , @Cube '@Cube'
               END
            
               -- Check if total qty for sku value able to fit into current caton box
               IF (@n_TotalSkuCube + @CurrCube > @Cube) OR
                  (@n_SkuCapacityLimit > @Cube) 
               BEGIN
                  -- Check if total qty for sku value able to fit into 1 new caton box
                  IF (@n_TotalSkuCube <= @Cube AND @n_TotalSkuCapacityLimit <= @Cube) 
                  BEGIN
                     --Close current carton and Open New Carton                           
                     UPDATE #OpenCarton
                     SET STS = '9'
                     WHERE CartonNo = @CartonNo
      
                     GOTO Open_New_Carton
                  END
               END
            END
         END 
      
         -----------------------------------------------
         -- Get Largest Carton Size and open one Carton
         -----------------------------------------------
         WHILE @CntCount <= @PickDetailQty
         BEGIN
            --Check Any Open Carton for this SKU 
            IF EXISTS (SELECT 1 FROM #OpenCarton WHERE Sts = 0 AND CartonType = @c_CartonType 
                       and PickSlipno = @c_PickSlipno 
                       AND ItemGroup1 = @c_ItemGroup1 
                       AND ItemGroup2 = @c_ItemGroup2
                       AND ItemGroup4 = @c_ItemGroup4)  
            BEGIN
               --SELECT 'Got Open carton, Get The Current Carton Info'
      
               SELECT @CartonNo = CartonNo,
                     @CurrWeight= CurrWeight, 
                     @CurrCube  = CurrCube, 
                     @CurrCount = CurrCount
               FROM #OpenCarton 
               WHERE Sts = 0 and CartonType = @c_CartonType and PickSlipno = @c_PickSlipno
               AND ItemGroup1 = @c_ItemGroup1 AND ItemGroup2 = @c_ItemGroup2
               AND ItemGroup4 = @c_ItemGroup4  --NJOW04
            END
            ELSE
            BEGIN
                      --SELECT 'No Open carton, Open one'
      Open_New_Carton:
               SET @cLabelNo = ''
               SET @CartonNo = ''
      
               --Get New CartonKey
               EXECUTE nspg_getkey
                     'CartonKey'
                     , 10
                     , @CartonNo OUTPUT
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
      
               IF @b_success <> 1
               BEGIN
                  SET @b_Success = 0
                  SET @n_continue = 3
                  SET @n_err = 60019
                  SET @c_ErrMsg = 'nspg_getkey ' + dbo.fnc_RTrim(@c_errmsg)
                  GOTO Quit_SP
               END
      
               SET @CurrWeight =0
               SET @CurrCube = 0
               SET @CurrCount =0 
      
               INSERT #OpenCarton (OrderKey, CartonNo, CartonType, CartonGroup, CurrWeight, CurrCube, CurrCount, Sts, PickSlipno, ItemGroup1, ItemGroup2, ItemGroup3, ItemGroup4) 
               SELECt @c_Orderkey, @CartonNo, @c_CartonType, @c_CartonGroup, @CurrWeight, @CurrCube, @CurrCount, '0', @c_PickSlipno, @c_ItemGroup1, @c_ItemGroup2, @c_ItemGroup3, @c_ItemGroup4 --NJOW04
            END
      
            IF @n_Debug = 4 
            BEGIN
               select @PickDetailQty 'Qty', @CntCount'Cnt' , @c_pickslipno 'PickSlipNO', @c_Orderkey 'Orderkey',  @CartonNo 'CartonNo',  @SKUCube 'SKUCUBE', @Cube 'CartonCube', @CurrCube 'CurrCube'
            END     
      
            SET @n_CapacityLimit =  CASE WHEN @n_PreCTNCapacityTol = 0 THEN 0
                                         ELSE ( (@SKUCUBE+ @CurrCube) * (@n_PreCTNCapacityTol / 100))
                                         END
                                                                    
            IF ((@SKUCUBE+ @CurrCube) <= @Cube AND (@n_CapacityLimit = 0)) 
            OR ((@SKUCUBE+ @CurrCube) <= @Cube AND (@n_CapacityLimit > 0 AND @n_CapacityLimit <= @Cube))
            BEGIN
               --insert item Into CARTON            
               INSERT #OpenCartonDetail(CartonNo, PickDetailKey, LabelNo, SKU, PackQty, 
                        Cube, 
                        Weight)
               SELECT @CartonNo, @c_PickDetailKey, '', @SKU, 1,    
                        @SKUCUBE , 
                        @SKUWeight 
            END
            ELSE
            BEGIN
               IF( @CurrWeight + @CurrCube + @CurrCount = 0 ) -- New Carton
               BEGIN 
                  SET @n_continue = 3
                  SET @n_err = 60029   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': New Carton Does not fit pack item:' + RTRIM(@sku)
                        +', Item Cube: ' + RTRIM(CONVERT(NCHAR(15), (@SKUCUBE+ @CurrCube))) + 
                        +', Sku Cube Tolerance: ' + RTRIM(CONVERT(NCHAR(15), @n_CapacityLimit)) + 
                        +', Carton Cube: ' + RTRIM(CONVERT(NCHAR(15), @Cube)) + '. (ispWAVPK15)'
                  GOTO QUIT_SP
               END
      
               --Close current carton and Open New Carton                           
               --Close Carton 
               UPDATE #OpenCarton
               SET STS = '9'
               WHERE CartonNo = @CartonNo
               GOTO Open_New_Carton
            END
                                
            --Next Quantity
            SELECT @CntCount = @CntCount + 1
                
            select @CurrCube = sum(b.Cube),
                  @CurrCount = sum(b.PackQty), 
                  @CurrWeight = sum(b.Weight)                  
            FROM #OpenCartonDetail b
            WHERE b.CartonNo = @CartonNo
               
            UPDATE #OpenCarton
            SET CurrCube = @CurrCube,
                  CurrCount = @CurrCount,
                  CurrWeight = @CurrWeight
            WHERE CartonNo = @CartonNo        
               
         END -- END WHILE
      
         UPDATE #PickDetail
         SET Sts ='9'                 
         WHERE PickSlipNo = @c_PickSlipNo AND PickDetailKey = @c_PickDetailKey
         
         DELETE CartonList 
         WHERE CartonKey IN (SELECT CartonKey FROM CartonListDetail WITH (NOLOCK) 
                             WHERE PICKDETAILKEY = @c_PickDetailKey)
      
         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 60020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update CartonList Table Failed. (ispWAVPK15)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END
      
         DELETE CartonListDetail WHERE PICKDETAILKEY = @c_PickDetailKey
         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 60021   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update CartonList Table Failed. (ispWAVPK15)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END
      
         SET @c_ItemGroup1_Prev = @c_ItemGroup1      
         SET @c_ItemGroup2_Prev = @c_ItemGroup2      
         SET @c_ItemGroup3_Prev = @c_ItemGroup3      
         SET @c_ItemGroup4_Prev = @c_ItemGroup4      
         
         FETCH NEXT FROM CUR_OrderList2 INTO @SKU, @c_StorerKey, @Qty, @c_PickSlipNo, @c_PickDetailKey
                                           , @c_ItemGroup1, @c_ItemGroup2, @c_ItemGroup3, @c_ItemGroup4, @c_BillToKey
      
      END --end of while
      CLOSE CUR_OrderList2
      DEALLOCATE CUR_OrderList2
   END
   
   --recheck all carton 
   IF @n_continue IN(1,2)
   BEGIN
      DECLARE cur_chkcarton CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
        SELECT CartonNo, CartonGroup, CurrCube, Sts 
        FROM #OpenCarton     
      
      OPEN cur_chkcarton  
             
      FETCH NEXT FROM cur_chkcarton INTO @CartonNo, @c_CartonGroup, @CurrCube, @c_sts
             
      WHILE @@FETCH_STATUS = 0 
      BEGIN
         SET @Cube          =0
         SET @MaxWeight     =0
         SET @MaxCount      =0
         SET @CartonLength  =0
         SET @CartonHeight  =0
         SET @CartonWidth   =0
         SET @FillTolerance =0
         SET @c_CartonType  =''
            
         SELECT top 1   @Cube          = Cube,
                        @MaxWeight     = MaxWeight,    
                        @MaxCount      = MaxCount,   
                        @CartonLength  = CartonLength, 
                        @CartonHeight  = CartonHeight,
                        @CartonWidth   = CartonWidth, 
                        @c_CartonType  = CartonType
         FROM Cartonization (NOLOCK) 
         WHERE Cartonizationgroup = @c_CartonGroup AND Cube >= @CurrCube
         ORDER BY Cube 
                  
         --Check Cube can fit in the smaller carton or not
         IF (@c_CartonType<>'')
         BEGIN
            UPDATE #OpenCarton
            SET CartonType = @c_CartonType
            WHERE CartonNo = @CartonNo                                                      
         END 
         
         IF @c_sts <> '9'
         BEGIN
            UPDATE #OpenCarton
            SET STS = '9'
            WHERE CartonNo = @CartonNo                                                      
         END                  
      
         FETCH NEXT FROM cur_chkcarton INTO @CartonNo, @c_CartonGroup, @CurrCube, @c_sts   	
      END
      CLOSE cur_chkcarton
      DEALLOCATE cur_chkcarton          	 
   END
  
   ----select * from #PickDetail
   --select * from #OpenCarton
   --select * from #OpenCartonDetail
   --set @b_Success =0
   --return
             
   --Re-Sequence The SEQNO, and Gen LabelNo for every carton
   IF @n_continue IN(1,2)
   BEGIN 
      DECLARE @PrevOrderkey NVARCHAR(15)
      SET @PrevOrderkey = ''
      
      DECLARE CUR_TempCartonList CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
              
      SELECT CartonNo, OrderKey,
             ISNULL(ID,''), Pickslipno  --NJOW02
      FROM #OpenCarton
      ORDER BY OrderKey, CartonNo
      
      OPEN CUR_TempCartonList
      FETCH NEXT FROM CUR_TempCartonList INTO @CartonNo, @c_Orderkey, @c_ID, @c_Pickslipno --NJOW02
         
      SET @CntCount = 1  
      WHILE (@@FETCH_STATUS <> -1)     
      BEGIN   
         --Reset counter when different Orderkey
         IF @PrevOrderkey <> @c_Orderkey
         BEGIN      	 
         	 SET @n_LastCartonNo = 0
         	 SELECT @n_LastCartonNo = ISNULL(MAX(CartonNo),0)
         	 FROM PACKDETAIL (NOLOCK) 
         	 WHERE Pickslipno = @c_Pickslipno
         	 
         	 IF @n_LastCartonNo > 0 
         	   SET @CntCount = @n_LastCartonNo + 1
         	 ELSE        	       	 
              SET @CntCount = 1
              
            SET @PrevOrderkey = @c_Orderkey
         END
        
         UPDATE #OpenCarton
         SET SeqNo = @CntCount
         WHERE CartonNo = @CartonNo
      
         --Gen Label                   
         EXECUTE isp_GenLabelNo_Wrapper
                  @c_PickSlipNo = @c_PickSlipno,       
                  @n_CartonNo   = 0,
                  @c_LabelNo    = @cLabelNo   OUTPUT   
      
         IF @cLabelNo = ''
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60022
            SET @c_errmsg = 'isp_GenLabelNo_Wrapper: Generate Empty Label# '
            GOTO QUIT_SP
         END
      
         IF @c_Id <> ''
         BEGIN
            UPDATE PICKDETAIL WITH (ROWLOCK)
            SET PICKDETAIL.CaseId = @cLabelNo,         
                PICKDETAIL.TrafficCop = NULL
            FROM PICKDETAIL 
            JOIN WAVEDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = WAVEDETAIL.Orderkey
            WHERE PICKDETAIL.Id = @c_ID
            AND PICKDETAIL.PickslipNo = @c_PickslipNo
            AND WAVEDETAIL.Wavekey = @c_Wavekey
         END
         ELSE
         BEGIN  --NJOW04
         	 DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD FOR
         	    SELECT Pickdetailkey, SUM(PackQty)
         	    FROM #OpenCartonDetail 
         	    WHERE CartonNo = @CartonNo
         	    GROUP BY Pickdetailkey
      
            OPEN CUR_PICK
            
            FETCH NEXT FROM CUR_PICK INTO @c_Pickdetailkey, @n_PackQty 
            
            WHILE @@FETCH_STATUS = 0
            BEGIN
            	  SELECT @n_PickQty = Qty
            	  FROM PICKDETAIL (NOLOCK)
            	  WHERE Pickdetailkey = @c_Pickdetailkey
            	  
            	  IF @n_PackQty >= @n_PickQty
            	  BEGIN
            	  	 UPDATE PICKDETAIL WITH (ROWLOCK)
            	  	 SET CaseId = @cLabelNo,
            	  	     Trafficcop = NULL
            	  	 WHERE Pickdetailkey = @c_Pickdetailkey    
            	  END
            	  ELSE
            	  BEGIN
            	  	 SET @n_SplitQty = @n_PickQty - @n_PackQty
      
                  EXECUTE nspg_GetKey  
                  'PICKDETAILKEY',  
                  10,  
                  @c_newpickdetailkey OUTPUT,  
                  @b_success OUTPUT,  
                  @n_err OUTPUT,  
                  @c_errmsg OUTPUT  
                  
                  IF NOT @b_success = 1  
                  BEGIN  
                     SELECT @n_continue = 3  
                  END  
                  
                  INSERT PICKDETAIL  
                         (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,  
                          Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,  
                          DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,  
                          ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,  
                          WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo   
                        , TaskDetailKey                                                
                         )  
                  SELECT @c_newpickdetailkey  
                       , PICKDETAIL.CaseID                              
                       , PickHeaderKey, OrderKey, OrderLineNumber, Lot,  
                         Storerkey, Sku, AltSku, UOM,  @n_splitqty , @n_splitqty, QtyMoved, Status,  
                         PICKDETAIL.DropId                                                        
                       , Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,  
                         ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,  
                         WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo  
                       , TaskDetailKey                                               
                  FROM PICKDETAIL (NOLOCK)  
                  WHERE PickdetailKey = @c_pickdetailkey           	  	 
      
                  SELECT @n_err = @@ERROR  
                  IF @n_err <> 0  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63332  
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispWAVPK15)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                  END  
                  
                  INSERT #PickDetail (PickDetailKey, OrderKey, OrderGroup, Route,  BillToKey
                        , SKU, Qty, PackQty, Storerkey, UOM, Sts, DropID, PickSlipNo
                        , ItemGroup1, TariffLookup, ID, B_Country)
                  SELECT @c_newpickdetailkey, OrderKey, OrderGroup, Route,  BillToKey
                        , SKU, @n_SplitQty, 0, Storerkey, UOM, Sts, DropID, PickSlipNo
                        , ItemGroup1, TariffLookup, ID, B_Country
                  FROM  #PickDetail
                  WHERE Pickdetailkey = @c_Pickdetailkey                 
                             
                  INSERT INTO #PICK_PIECE (PickDetailKey, PickSlipNo , Storerkey, SKU, Qty, ItemGroup1, ItemGroup2,ItemGroup3
                                           ,ItemGroup4, ItemStyle, ItemBUSR1, ItemColor, ItemSize , ItemMeasure, BillToKey)
                  SELECT @c_newpickdetailkey, PickSlipNo , Storerkey, SKU, @n_SplitQty, ItemGroup1, ItemGroup2,ItemGroup3
                         ,ItemGroup4, ItemStyle, ItemBUSR1, ItemColor, ItemSize , ItemMeasure, BillToKey
                  FROM #PICK_PIECE
                  WHERE Pickdetailkey = @c_Pickdetailkey           
      
                  UPDATE PICKDETAIL WITH (ROWLOCK)  
                  SET PICKDETAIL.CaseID = @cLabelno  
                     ,Qty = @n_packqty  
                     ,UOMQTY = @n_packqty   
                     ,TrafficCop = NULL  
                  WHERE Pickdetailkey = @c_pickdetailkey  
                  
                  SELECT @n_err = @@ERROR  
                  IF @n_err <> 0  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63333  
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispWAVPK15)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                  END  
                  
                  UPDATE #PickDetail
                  SET Qty = @n_PackQty
                  WHERE Pickdetailkey = @c_Pickdetailkey
                  
                  --NJOW05
                  UPDATE #PICK_PIECE 
                  SET Qty = @n_PackQty
                  WHERE Pickdetailkey = @c_Pickdetailkey
                             	  	 
            	  	 UPDATE #OpenCartonDetail
            	  	 SET Pickdetailkey  = @c_NewPickdetailkey
            	  	 WHERE Pickdetailkey = @c_Pickdetailkey
            	  	 AND CartonNo <> @CartonNo         	  	 
            	  END
            	  
               FETCH NEXT FROM CUR_PICK INTO @c_Pickdetailkey, @n_PackQty 
            END
            CLOSE CUR_PICK
            DEALLOCATE CUR_PICK         
         END
      
         UPDATE #OpenCartonDetail
         SET LabelNo = @cLabelNo
         WHERE CartonNo = @CartonNo
      
         SELECT @CntCount = @CntCount + 1
      
         FETCH NEXT FROM CUR_TempCartonList INTO @CartonNo, @c_Orderkey, @c_ID, @c_Pickslipno --NJOW02
      
      END --end of while
      
      CLOSE CUR_TempCartonList
      DEALLOCATE CUR_TempCartonList
   END

   --Generate Carton Count by Pickslip
   IF @n_continue IN(1,2)
   BEGIN    
      DECLARE @PrevPickSlipno   NVARCHAR(10)
      SET @PrevPickSlipno = ''   
      
      DECLARE CartonCntByPickslip_Cursor CURSOR LOCAL FAST_FORWARD
      FOR
         SELECT DISTINCT PickslipNo, CartonNo FROM #OpenCarton 
         ORDER BY PickSlipNo, CartonNo
      OPEN CartonCntByPickslip_Cursor
      
      FETCH NEXT FROM CartonCntByPickslip_Cursor 
      INTO @c_PickSlipno, @CartonNo
      
      WHILE @@FETCH_STATUS = 0
      BEGIN
            --Reset counter when different PickSlipno
         IF @PrevPickSlipno <> @c_PickSlipno
         BEGIN
         	 SET @n_LastCartonNo = 0
         	 SELECT @n_LastCartonNo = ISNULL(MAX(CartonNo),0)
         	 FROM PACKDETAIL (NOLOCK) 
         	 WHERE Pickslipno = @c_Pickslipno
      
         	 IF @n_LastCartonNo > 0 
         	   SET @CntCount = @n_LastCartonNo + 1
         	 ELSE        	       	 
              SET @CntCount = 1
      
            SET @PrevPickSlipno = @c_PickSlipno
         END
         
         UPDATE #OpenCarton 
         SET CartonSeq = @CntCount
         WHERE PickSlipNo = @c_PickSlipno and CartonNo = @CartonNo
      
         SELECT @CntCount = @CntCount + 1
                                                         
         FETCH NEXT FROM CartonCntByPickslip_Cursor INTO @c_PickSlipno, @CartonNo
      END 
         
      CLOSE CartonCntByPickslip_Cursor;   
      DEALLOCATE CartonCntByPickslip_Cursor
   END

   -------------------
   Begin Transaction
   -------------------
   --Gen PackDetail 
   IF @n_continue IN(1,2)
   BEGIN     
      DECLARE PackDetail_Cursor CURSOR LOCAL FAST_FORWARD
      FOR
         SELECT Distinct PickSlipNo
         FROM #PickDetail
      OPEN PackDetail_Cursor
      
      FETCH NEXT FROM PackDetail_Cursor 
      INTO @c_PickSlipno
      
      WHILE @@FETCH_STATUS = 0   
      BEGIN      
         --DELETE PACKDETAIL WITH (ROWLOCK) WHERE PickSlipNo = @c_PickSlipno
         
         DELETE PACKDETAIL
         FROM PACKDETAIL (NOLOCK)
         LEFT JOIN PICKDETAIL (NOLOCK) ON PACKDETAIL.Labelno = PICKDETAIL.CaseID         
         WHERE PACKDETAIL.PickSlipNo = @c_PickSlipno
         AND PICKDETAIL.CaseID IS NULL
                     
         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 60023   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PACKDETAIL Table Failed. (ispWAVPK15)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END
                      
         INSERT INTO PACKDETAIL ( LabelLine, PickSlipNo,CartonNo,LabelNo,StorerKey,SKU, Qty,RefNo,ArchiveCop
                                 ,ExpQty,UPC,DropID,RefNo2)        
         SELECT RIGHT('00000' + Convert( NVARCHAR(10), ROW_NUMBER() OVER(PARTITION BY a.pickslipno,b.cartonno ORDER BY a.PickSlipNo, b.cartonno, MAX(PE.ItemStyle), MAX(PE.ItemBusr1), MAX(PE.ItemColor), MAX(PE.ItemSize), MAX(PE.Itemmeasure))),5), 
                a.PickSlipNo, c.CartonSeq, b.LabelNo, a.StorerKey, a.SKU , sum(b.PackQty), '', null
               , 0, null, CASE WHEN a.uom = '2' THEN a.dropid ELSE '' END,''
         from #PickDetail a
         JOIN #OpenCartonDetail b on b.PickDetailKey = a.PickDetailKey
         JOIN #OpenCarton c on c.CartonNo = b.CartonNo AND c.PickSlipNo = a.PickSlipNo
         LEFT JOIN #PICK_PIECE PE ON a.pickdetailkey = PE.Pickdetailkey AND a.Pickslipno = PE.Pickslipno  --NJOW03
         WHERE a.PickSlipNo = @c_PickSlipno
         GROUP by a.PickSlipNo, b.CartonNo, b.LabelNo
               , a.SKU, a.StorerKey, c.CartonSeq
               , CASE WHEN a.uom = '2' THEN a.dropid ELSE '' END
         ORDER BY a.PickSlipNo, b.cartonno, MAX(PE.ItemStyle), MAX(PE.ItemBusr1), MAX(PE.ItemColor), MAX(PE.ItemSize), MAX(PE.Itemmeasure), a.SKU
               
         IF @@ERROR <> 0
         BEGIN
            SET @b_Success = 0
            SET @n_continue = 3
            SET @n_err = 60024
            SET @c_ErrMsg = 'Failed to Added PackDetail'
            GOTO Quit_SP
         END
      
         INSERT INTO PACKINFO ( PickSlipNo,CartonNo,[Cube],Qty
                              ,CZ.CartonType, [Length], Width, Height)        
         SELECT  PD.PickSlipNo, PD.CartonNo
                              ,CASE WHEN c.FullCase = 'Y' THEN 0 ELSE CZ.[Cube]END  
                              ,ISNULL(SUM(PD.Qty),0)
                              ,CASE WHEN c.FullCase = 'Y' THEN '' ELSE CZ.CartonType END  
                              ,CASE WHEN c.FullCase = 'Y' THEN 0 ELSE CZ.CartonLength END 
                              ,CASE WHEN c.FullCase = 'Y' THEN 0 ELSE CZ.CartonWidth END 
                              ,CASE WHEN c.FullCase = 'Y' THEN 0 ELSE CZ.CartonHeight END 
         FROM #OpenCarton c 
         JOIN PACKDETAIL PD WITH (NOLOCK) ON c.PickSlipNo = PD.PickSlipNo AND c.CartonSeq = PD.CartonNo      
         JOIN CARTONIZATION CZ WITH (NOLOCK) ON (CZ.CartonizationGroup = c.CartonGroup)
                                             AND(CZ.CartonType = c.CartonType)
         WHERE C.PickSlipNo = @c_PickSlipno
         GROUP by PD.PickSlipNo, PD.CartonNo, CZ.[Cube]
               ,  CZ.CartonType, CZ.CartonLength,CZ.CartonWidth, CZ.CartonHeight
               ,  C.FullCase 
      
         IF @@ERROR <> 0
         BEGIN
            SET @b_Success = 0
            SET @n_continue = 3
            SET @n_err = 60025
            SET @c_ErrMsg = 'Failed to Added PackInfo'
            GOTO Quit_SP
         END
      
         EXEC isp_AssignPackLabelToOrderByLoad
               @c_PickSlipNo= @c_PickSlipNo
            ,  @b_Success   = @b_Success  OUTPUT
            ,  @n_Err       = @n_Err      OUTPUT
            ,  @c_ErrMsg    = @c_ErrMsg   OUTPUT
      
         IF @b_Success <> 1
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 60026
            SET @c_ErrMsg = 'NSQL' +  CONVERT(CHAR(5),@n_Err)  + ':'  
                           + 'Error Executing isp_AssignPackLabelToOrderByLoad.(ispWAVPK15)'
            GOTO QUIT_SP
         END
      
         SET @c_PickSlipno = ''                    
      
         FETCH NEXT FROM PackDetail_Cursor INTO @c_PickSlipno
      END 
         
      CLOSE PackDetail_Cursor;
      DEALLOCATE PackDetail_Cursor
   END

   ----------Update DROP ID---------- 
   IF @n_continue IN(1,2)
   BEGIN
      DECLARE CUR_PICK CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      	SELECT ISNULL(LLI.ID,''), PD.PickDetailKey, PD.UOM, Loc.LocationType, LLI.Qty, ISNULL(WAVPICKQTY.Qty, 0)
      	FROM Orders O (nolock)
      	JOIN OrderDetail OD (NOLOCK) ON  O.Orderkey = OD.Orderkey
      	JOIN PickDetail PD (NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber
       JOIN LotxLocxID LLI (NOLOCK) ON PD.Lot = LLI.Lot AND PD.Loc = LLI.Loc AND PD.Id = LLI.Id
       JOIN Loc (NOLOCK) ON PD.Loc = LOC.Loc
       JOIN WAVEDETAIL WD (NOLOCK) ON O.Orderkey = WD.Orderkey
       OUTER APPLY (SELECT SUM(PD2.Qty) AS Qty
                    FROM PICKDETAIL PD2 (NOLOCK)
      	 	           JOIN WAVEDETAIL WD2 (NOLOCK) ON PD2.Orderkey = WD2.Orderkey  
      	 	           WHERE WD2.Wavekey = WD.Wavekey 
      	 	           AND PD2.Lot = PD.Lot AND PD2.Loc = PD.Loc AND PD2.Id = PD.Id) AS WAVPICKQTY
      	WHERE WD.Wavekey = @c_Wavekey
      		AND O.Status = '3' 
      		AND PD.Status = '0' 
      		AND Loc.LocationType = 'OTHER'  
      		and (PD.DropID = '' OR PD.DropID IS NULL)
      		AND (PD.CaseID <> '' AND PD.CaseID IS NOT NULL) 
      		AND LLI.Qty > 0
       ORDER BY PD.UOM, PD.CaseID, LLI.ID, PD.LOC, PD.SKU
      
      OPEN CUR_PICK
      
      FETCH NEXT FROM CUR_PICK INTO @c_ID, @c_PickDetailKey, @c_UOM, @c_LocationType, @n_LLIQty, @n_PDQty
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN         	    	     	
      	IF @c_UOM = 2 OR (@c_LocationType = 'OTHER' AND @n_PDQty = @n_LLIQty)
      	BEGIN
      		Set @c_DropID = @c_ID
      	
      		IF  LEN(@c_ID)=18 AND @c_ID like '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' 
      			AND dbo.fnc_CalcCheckDigit_M10('00'+LEFT(@c_ID,17),1) = '00' + @c_ID   			
      				Set @c_DropID = '00' + @c_ID
      
      	  UPDATE PICKDETAIL WITH(ROWLOCK)
      	  	SET DropID = @c_DropID,
      	  	    Status = '3',
      	  	    Trafficcop = NULL
      	  WHERE PickDetailKey = @c_PickDetailKey   	     
      	   
         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 60027   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispWAVPK15)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         END   	  
      END
      
         FETCH NEXT FROM CUR_PICK INTO @c_ID, @c_PickDetailKey, @c_UOM, @c_LocationType, @n_LLIQty, @n_PDQty
      END   
      CLOSE CUR_PICK
      DEALLOCATE CUR_PICK
   END
        
QUIT_SP:
   IF @b_Success =1 --When Success
   BEGIN                                 
      --insert CartonList
      INSERT CartonList (CartonKey, SeqNo, CartonType,CurrWeight,CurrCube,CurrCount,Status)
      SELECT CartonNo, SeqNo, Cartontype, CurrWeight, CurrCube, CurrCount, Sts  
      FROM #OpenCarton

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 60027   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert CartonList Table Failed. (ispWAVPK15)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END

      ----Insert Cartonization Result   
      INSERT CartonListDetail (CartonKey, SKU, Qty, OrderKey, PickDetailKey, LabelNo)
      SELECT a.CartonNo, SKU, Sum(PackQty), b.OrderKey, a.PickDetailKey, a.LabelNo
      FROM #OpenCartonDetail a
      JOIN #OpenCarton b on b.CartonNo = a.CartonNo
      GROUP BY a.CartonNo, a.PickDetailKey, a.LabelNo, a.SKU,  b.OrderKey
      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 60028   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert CartonListdetail Table Failed. (ispWAVPK15)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END
         
      if @n_Debug = 99
      BEGIN
         select * from #OpenCarton

         select CartonNo, PickDetailKey, LabelNo, SKU, Sum(PackQty)'PackQty', sum(Cube)'SumCube', sum (Weight) 'SumWeight'
         from #OpenCartonDetail         
         group by CartonNo, PickDetailKey, LabelNo, SKU

         SELECT * from #OpenCartonDetail
      END
   END

   --Clear Cursor if cursor still exists   
   IF CURSOR_STATUS('LOCAL' , 'CUR_OrderList') in (0 , 1)          
   BEGIN          
      CLOSE CUR_OrderList          
      DEALLOCATE CUR_OrderList          
   END

   IF CURSOR_STATUS('LOCAL' , 'CUR_OrderList2') in (0 , 1)          
   BEGIN          
      CLOSE CUR_OrderList2          
      DEALLOCATE CUR_OrderList2          
   END

   IF CURSOR_STATUS('LOCAL' , 'CUR_OrderList3') in (0 , 1)          
   BEGIN          
      CLOSE CUR_OrderList3
      DEALLOCATE CUR_OrderList3
   END

   IF CURSOR_STATUS('LOCAL' , 'CUR_TempCartonList') in (0 , 1)          
   BEGIN          
      CLOSE CUR_TempCartonList
      DEALLOCATE CUR_TempCartonList
   END

   IF CURSOR_STATUS('LOCAL' , 'PackDetail_Cursor') in (0 , 1)          
   BEGIN          
      CLOSE PackDetail_Cursor
      DEALLOCATE PackDetail_Cursor
   END

   IF CURSOR_STATUS('LOCAL' , 'CartonCntByPickslip_Cursor') in (0 , 1)          
   BEGIN          
      CLOSE CartonCntByPickslip_Cursor
      DEALLOCATE CartonCntByPickslip_Cursor
   END

   -- DROP TEMP TABLE
   IF OBJECT_ID('tempdb..#OpenCarton','u') IS NOT NULL
   DROP TABLE #OpenCarton;

   IF OBJECT_ID('tempdb..#OpenCartonDetail','u') IS NOT NULL
   DROP TABLE #OpenCartonDetail;

   IF OBJECT_ID('tempdb..#PickDetail','u') IS NOT NULL
   DROP TABLE #PickDetail;

   IF @n_Continue=3  -- Error Occured - Process AND Return
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispWAVPK15'    
      RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012    
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