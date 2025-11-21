SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* SP: ispWAVNK01                                                       */
/* Creation Date: 08 March 2017                                         */
/* Copyright: IDS                                                       */
/* Written by: Barnett                                                  */
/*                                                                      */
/* Purpose: WMS-1218 CN-Nike SDC WMS PreCartonization                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* RDTMsg :                                                             */
/*                                                                      */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 08-MAR-2017 Barnett  1.0   Initial                                   */
/* 10-JUL-2017 Barnett  1.1   Remove carton HxLxW checking (BL01)       */
/* 26-JUL-2017 Barnett  1.2   UOM 2 Case group by Drop ID (BL02)        */
/* 24-JAN-2018 Barnett  1.3   WMS-3682 Add Dynamic SQL grouping         */
/*                            logic, Add new CartonGroup logic          */
/* 24-FEB-2018 Barnett  1.4   WMS-3682 if sku.stdcube >                 */
/*                            cartonization.cube, stop process(BL03)    */
/* 04-JUL-2018 Wan01    1.5   WMS-5447:CN-NIKESDC_WMS_PreCartonization_CR*/
/* 23-JUL-2021 NJOW01   1.6   WMS-17457 update orderdetail for grouping */
/* 26-APR-2023 NJOW02   1.7   WMS-22442 include all UOM when update     */
/*                            orderdetail for grouping                  */
/* 26-APR-2023 NJOW02   1.7   DEVOPS Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[ispWAVNK01](
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
   
   declare @n_Debug         INT

   DECLARE    @c_Orderkey              VARCHAR(15)
            , @CartonizationRuleKey    NVARCHAR(20)
            , @c_PickSlipno            NVARCHAR(10)
            , @cLabelNo                NVARCHAR(20)
            , @c_PickDetailKey         NVARCHAR(18)
            , @c_DropID                NVARCHAR(20)
            , @c_NewPickDetailKey      NVARCHAR(18)
            , @c_StorerKey             NVARCHAR(15)
            , @c_ConsigneeKey          NVARCHAR(18)            --(Wan01)
            , @c_CartonGroup           NVARCHAR(10)
            , @c_CartonType            NVARCHAR(10)   
            , @n_StartTCnt             INT
            , @CartonNo                INT                        
            , @n_continue              INT
            , @SKU                     NVARCHAR(20)
            , @Qty                     INT
            , @PickDetailQty           INT
            , @CntCount                INT

   DECLARE  @CurrUseSequence  INT,
            @Cube             FLOAT,
            @MaxWeight        FLOAT,
            @MaxCount         INT,
            @CartonLength     FLOAT,
            @CartonHeight     FLOAT,
            @CartonWidth      FLOAT,
            @FillTolerance    INT,
            @CurrWeight       FLOAT,
            @CurrCube         FLOAT,
            @CurrCount        INT

   DECLARE  @SKULength        FLOAT,
            @SKUCUBE          FLOAT,
            @SKUWeight        FLOAT,
            @SKUHeight        FLOAT, 
            @SKUWidth         FLOAT,
            @SKUBusr7         NVARCHAR(20),
            @HangerCube       FLOAT,
            @HangerWeight     FLOAT,
            @OrderGroup       NVARCHAR(20),
            @OrderRoute       NVARCHAR(10)
            , @c_Notes1                NVARCHAR(15)
            , @c_PrevField01           NVARCHAR(60)
            , @c_PrevField02           NVARCHAR(60)
            , @c_PrevField03           NVARCHAR(60)
            , @c_PrevField04           NVARCHAR(60)
            , @c_PrevField05           NVARCHAR(60)
            , @c_PrevField06           NVARCHAR(60)
            , @c_PrevField07           NVARCHAR(60)
            , @c_PrevField08           NVARCHAR(60)
            , @c_PrevField09           NVARCHAR(60)
            , @c_PrevField10           NVARCHAR(60)

            , @c_PreCTNLevel        CHAR(1)              --(Wan01)
            , @c_PrevDropID         NVARCHAR(20)         --(Wan01)
            , @c_Loadkey            NVARCHAR(10)         --(Wan01)   
            , @c_PrevLoadkey        NVARCHAR(10)         --(Wan01) 
            , @c_PrevOrderkey       NVARCHAR(10)         --(Wan01) 
            , @c_PackOrderkey       NVARCHAR(10)         --(Wan01)   
            , @c_PrevPickSlipNo     NVARCHAR(10)         --(Wan01)
            , @c_Facility           NVARCHAR(10)         --(Wan01)      
            , @c_Zone               NVARCHAR(10)         --(Wan01)

            , @b_Reusable           BIT                  --(Wan01)
            , @c_DocKey             NVARCHAR(10)         --(Wan01)
            , @c_SKUSUSR3           NVARCHAR(20)         --(Wan01)
            , @n_TotalCube          FLOAT                --(Wan01)
            , @c_GetOrderkey        NVARCHAR(10)         --NJOW01
            , @c_OrderLineNumber    NVARCHAR(5)          --NJOW01
            , @c_OrderDetRefNote1   NVARCHAR(1000)       --NJOW01
            , @n_Discount           FLOAT                --NJOW01

   --Dynamic SQL use Variable
   DECLARE @c_ListName NVARCHAR(10)
         ,@c_Code NVARCHAR(30) -- e.g. ORDERS01
         ,@c_Description NVARCHAR(250)
         ,@c_TableColumnName NVARCHAR(250)  -- e.g. ORDERS.Orderkey
         ,@c_TableName  NVARCHAR(30)
         ,@c_ColumnName NVARCHAR(30)
         ,@c_ColumnType NVARCHAR(10)
         ,@c_SQLField NVARCHAR(2000)
         ,@c_SQLWhere NVARCHAR(2000)
         ,@c_SQLGroup NVARCHAR(2000)
         ,@c_SQLDYN01 NVARCHAR(2000)
         ,@c_SQLDYN02 NVARCHAR(2000)
         ,@c_SQLDYN03 NVARCHAR(2000) 
         ,@c_Field01 NVARCHAR(60)
         ,@c_Field02 NVARCHAR(60)
         ,@c_Field03 NVARCHAR(60)
         ,@c_Field04 NVARCHAR(60)
         ,@c_Field05 NVARCHAR(60)
         ,@c_Field06 NVARCHAR(60)
         ,@c_Field07 NVARCHAR(60)
         ,@c_Field08 NVARCHAR(60)
         ,@c_Field09 NVARCHAR(60)
         ,@c_Field10 NVARCHAR(60)
         ,@n_cnt int
         ,@n_NoOfGroupField      INT 
         ,@c_FoundLoadkey NVARCHAR(10)            
   
   SELECT @b_success = 1 --Preset to success
   SET @n_continue = 1
   SET @n_Debug = 0
   SET @n_StartTCnt=@@TRANCOUNT

   IF EXISTS ( SELECT 1 FROM WAVE WITH (NOLOCK) WHERE Wavekey = @c_WaveKey and DispatchPiecePickMethod <> 'INLINE')
   BEGIN
         SET @b_Success = 0
         SET @n_continue = 3  
         SET @n_err = "60001"
         SET @c_ErrMsg = "Wave.DispatchPiecePickMethod is not INLINE"
         GOTO QUIT_SP
   END

   -- IF CaseId exists in PickDetil, end process.
   IF EXISTS (SELECT PD.CaseId FROM WaveDetail WD WITH (NOLOCK)
               JOIN PickDetail PD  WITH (NOLOCK) ON PD.OrderKey = WD.OrderKey
               WHERE WD.WaveKey =  @c_WaveKey and isnull(CaseId,'') <>''
               )
   BEGIN
         SET @b_Success = 0
         SET @n_err = "60002"
         SET @c_ErrMsg = "Case ID already got data, cannot run pre-cartonization"
         GOTO QUIT_SP
   END

   IF OBJECT_ID('tempdb..#OpenCarton','u') IS NOT NULL
   DROP TABLE #OpenCarton;

   -- Store Open Carton 
   CREATE TABLE #OpenCarton (
         RowRef      INT   IDENTITY(1,1)  PRIMARY KEY,         --(Wan01)
         SeqNo       INT   NULL DEFAULT (0),                   --(Wan01)
         OrderKey    NVARCHAR(20), 
         PickSlipNo  NVARCHAR(10),                             --(Wan01)        
         CartonNo    INT,
         CartonType  NVARCHAR(20),
         CartonGroup NVARCHAR(20),
         CurrWeight  Float,
         CurrCube    Float,
         CurrCount   INT,
         Sts         VARCHAR(1), -- 0 open, 9 closed
         UOM         CHAR(1)                                   --(Wan01)
   )

   IF OBJECT_ID('tempdb..#OpenCartonDetail','u') IS NOT NULL
   DROP TABLE #OpenCartonDetail;

   -- Store Open Carton 
   CREATE TABLE #OpenCartonDetail (  
         RowRef            BIGINT   IDENTITY(1,1)  PRIMARY KEY,--(Wan01)           
         CartonNo          INT,
         Orderkey          NVARCHAR(10),                       --(Wan01)
         PickDetailKey     NVARCHAR(18),
         LabelNo           NVARCHAR(20),
         SKU               NVARCHAR(20),
         PackQty           INT,
         Cube              FLOAT, 
         Weight            FLOAT 
   )

   IF OBJECT_ID('tempdb..#PickDetail','u') IS NOT NULL
         DROP TABLE #PickDetail;

   -- Store PickDetail by OrderKey
   CREATE TABLE #PickDetail (
         PickDetailKey   NVARCHAR(18) NOT NULL  PRIMARY KEY,   --(Wan01)
         Loadkey         NVARCHAR(10),                         --(Wan01)  
         PackOrderkey    NVARCHAR(10),                         --(Wan01)    
         OrderKey        NVARCHAR(20),
         OrderLineNumber NVARCHAR(5) ,
         SKU             NVARCHAR(20),
         Qty             INT,
         PackQty         INT,
         Storerkey       NVARCHAR(30),
         Consignee       NVARCHAR(30),
         UOM             NVARCHAR(10),
         Sts             VARCHAR(1),
--         LabelNo         NVARCHAR(20),                       --(Wan01)
         DropID          NVARCHAR(20) 
--         CartonGroup     NVARCHAR(10),                       --(Wan01)
--         CartonType      NVARCHAR(10),                       --(Wan01)
         )
   
   --(Wan01) - START
   SELECT TOP 1 
            @c_Facility = OH.Facility
         ,  @c_Storerkey = OH.Storerkey
   FROM WAVE  WH WITH (NOLOCK)
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON (WH.Wavekey = WD.Wavekey)
   JOIN ORDERS OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)
   WHERE WH.WaveKey = @c_WaveKey

   SET @b_Success = 1
   EXEC nspGetRight  
         @c_Facility            
      ,  @c_StorerKey             
      ,  ''       
      ,  'NKSPreCartonLevel'             
      ,  @b_Success        OUTPUT    
      ,  @c_PreCTNLevel    OUTPUT  
      ,  @n_err            OUTPUT  
      ,  @c_errmsg         OUTPUT

   IF @b_Success <> 1
   BEGIN 
      SET @n_Continue= 3    
      SET @n_Err     = 60020   
      SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Executing nspGetRight: '  
                     + '.(ispWAVNK01)'
      GOTO QUIT_SP  
   END
   --(Wan01) - END

   INSERT #PickDetail (PickDetailKey, OrderKey
         , SKU, Qty, PackQty, Storerkey, UOM, Sts, DropID, Consignee, OrderLineNumber
         ,Loadkey, PackOrderkey                                                     --(Wan01)
         )
   SELECT PD.PickDetailKey, Orderkey = CASE WHEN @c_PreCTNLevel = 'L' THEN '' ELSE O.OrderKey END --(Wan01)
         ,PD.Sku, PD.Qty, 0, PD.Storerkey, PD.UOM, '0', DropID, 'NKS' + O.ConsigneeKey, PD.OrderLineNumber
         ,Loadplankey = CASE WHEN @c_PreCTNLevel = 'L' THEN O.Loadkey ELSE '' END   --(Wan01)
         ,PackOrderkey= PD.OrderKey                                                 --(Wan01)
   FROM WaveDetail WD  WITH (NOLOCK)
   JOIN Orderdetail OD WITH (NOLOCK) ON OD.OrderKey = WD.OrderKey
   JOIN PickDetail PD  WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber 
   JOIN Orders O WITH (NOLOCK) ON O.OrderKey = WD.OrderKey
   WHERE WD.WaveKey =  @c_WaveKey
   ORDER BY Loadplankey, PD.OrderKey, PD.UOM                                        --(Wan01)

   IF @@ROWCOUNT = 0
   BEGIN
      SET @b_Success = 0
      SET @n_continue = 3
      SET @n_err = "60003"
      SET @c_ErrMsg = "No PickDetail line"
      GOTO QUIT_SP
   END
      
   --Checking SKU cube & Carton Cube before process. --BL03 start
   DECLARE CheckCube_Cursor CURSOR FAST_FORWARD
   FOR
      SELECT a.SKU, a.Orderkey, a.StorerKey, OD.ConsigneeKey--'NKS' +  OD.ConsigneeKey
      FROM #PickDetail a
      JOIN Orders OD (NOLOCK) ON OD.OrderKey = a.OrderKey
      ORDER BY Orderkey, SKU
               
   OPEN CheckCube_Cursor

   FETCH NEXT FROM CheckCube_Cursor 
   INTO @SKU, @c_Orderkey, @c_StorerKey, @c_ConsigneeKey

   WHILE @@FETCH_STATUS = 0
   BEGIN     
      IF (SELECT SUSR1 FROM Storer (NOLOCK)  WHERE StorerKey = @c_ConsigneeKey) ='Reusable'
      BEGIN
         --Reusable, use consignee find carton group         
         SELECT @SKUCUBE = SKU.STDCube   
         FROM SKU SKU(NOLOCK)                   
         WHERE SKU.SKU = @SKU AND SKU.StorerKey = @c_StorerKey

         SELECT @c_CartonGroup = CartonGroup
         FROM Storer a (NOLOCK)        
         WHERE a.Type = '2' and a.StorerKey = @c_ConsigneeKey
      END
      ELSE
      BEGIN   
         --Not Reusable, use SKU find carton group         
         SELECT @c_CartonGroup = CLK.UDF01,
                  @SKUCUBE = SKU.STDCube                 
         FROM SKU SKU(NOLOCK) 
         JOIN CodelKup CLK (NOLOCK) ON CLK.ListName='SKUGROUP' AND CLK.Code = SKU.BUSR7         
         WHERE SKU.SKU = @SKU AND SKU.StorerKey = @c_StorerKey                 
      END
    
      --Check if any SKU.Cube bigger than carton.cube   
      IF EXISTS ( SELECT 1                           
                  FROM Cartonization (NOLOCK) 
                  WHERE Cartonizationgroup = @c_CartonGroup
                  Having Max(Cube) < @SKUCUBE
      )
      BEGIN
         SET @b_Success = 0
         SET @n_continue = 3  
         SET @n_err = "60004"
         SET @c_ErrMsg = 'sku.stdcube > cartonization.cube'
         GOTO QUIT_SP
      END
                                                
      FETCH NEXT FROM CheckCube_Cursor 
   INTO @SKU, @c_Orderkey, @c_StorerKey, @c_ConsigneeKey
   END 
      
   CLOSE CheckCube_Cursor;
   DEALLOCATE CheckCube_Cursor
   -- BL03 end
  

   --Temp Table for Cartonization Rule
   IF OBJECT_ID('tempdb..#Temp','u') IS NOT NULL
         DROP TABLE #Temp;

   -- Store Stock in Inventory 
   CREATE TABLE #Temp (  
   OrderKey NVARCHAR(20),
   CtnMaxQty int,
   MixSKU char(1),
   GroupType char(1),
   MixSize char(1)
   )

   IF OBJECT_ID('tempdb..##CartonType','u') IS NOT NULL
      DROP TABLE #CartonList;
      CREATE TABLE #CartonType(
      CartonType NVARCHAR(20)
      )


   -- Handle The Full UCC first, PickDetail.UOM = 2    
   DECLARE CUR_OrderList CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      -- BL02 Start
      SELECT DropID, OrderKey, SKU, Storerkey, Sum(Qty) 'Qty'
            ,Loadkey                                                                --(Wan01)
      FROM #PickDetail 
      WHERE UOM = 2 and Sts = '0' -- Full UCC only
      Group By DropID, OrderKey, SKU, Storerkey, Loadkey                            --(Wan01)
      ORDER BY DropID                                                               --(Wan01) 
       --SELECT PickDetailKey, OrderKey, SKU, Storerkey, Qty FROM #PickDetail WHERE UOM = 2 and Sts = '0' -- Full UCC only
       
   OPEN CUR_OrderList  
   FETCH NEXT FROM CUR_OrderList INTO @c_DropID, @c_Orderkey, @SKU, @c_StorerKey, @Qty
                                    , @c_Loadkey                                    --(Wan01)
      
   WHILE (@@FETCH_STATUS <> -1)     
   BEGIN   
      --Reset Variable
      SET @OrderGroup = ''
      SET @OrderRoute = ''      
      SET @c_PickSlipno = ''
      SET @cLabelNo = ''
      SET @c_ConsigneeKey = ''
   
      IF @c_DropID <> @c_PrevDropID
      BEGIN
         --(Wan01) - START
         SET @c_Zone = '3'
         IF @c_Loadkey <> '' 
         BEGIN
            SELECT TOP 1 
                   @OrderGroup = OrderGroup,
                   @OrderRoute = Route,
                   @c_ConsigneeKey = 'NKS' + ConsigneeKey
            FROM Orders (NOLOCK)
            WHERE Loadkey = @c_Loadkey

            SELECT @c_PickSlipno = PickheaderKey 
            FROM PICKHEADER (NOLOCK) 
            WHERE LoadKey = @c_Loadkey
            AND   ExternOrderkey = @c_Loadkey

            SET @c_PackOrderkey = ''
            SET @c_Zone = '7'

            SET @c_DocKey = @c_Loadkey
         END
         ELSE
         BEGIN
            SELECT @OrderGroup = OrderGroup,
                   @OrderRoute = Route,
                   @c_ConsigneeKey = 'NKS' + ConsigneeKey
            FROM Orders (NOLOCK)
            WHERE OrderKey = @c_Orderkey

            --Gen PickSlip
            SELECT @c_PickSlipno = PickheaderKey   
            FROM PickHeader (NOLOCK)  
            WHERE Orderkey = @c_Orderkey

            SET @c_DocKey = @c_Orderkey
         END
         --(Wan01) - END
                          
         --If PickSlip not found, Create Pickheader      
         IF ISNULL(@c_PickSlipno ,'') = ''  
         BEGIN  
            EXECUTE dbo.nspg_GetKey   
            'PICKSLIP',   9,   @c_Pickslipno OUTPUT,   @b_Success OUTPUT,   @n_Err OUTPUT,   @c_Errmsg OUTPUT      
               
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 60004   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Getkey(PICKSLIP) (ispWAVNK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
               GOTO QUIT_SP
            END
                    
            SELECT @c_Pickslipno = 'P'+@c_Pickslipno      
                             
            INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, TrafficCop, Loadkey, Wavekey, Storerkey)  --(Wan01)  
            VALUES (@c_Pickslipno , @c_Loadkey, @c_Orderkey, '0', @c_Zone, '', @c_Loadkey, @c_Wavekey, @c_Storerkey)                   --(Wan01)
               
            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 60005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Pickheader Table (ispWAVNK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
               GOTO QUIT_SP
            END

         END
   
         IF (select SUSR1 FROM Storer (NOLOCK)  WHERE StorerKey = @c_ConsigneeKey) ='Reusable'
         BEGIN
            /*
            -  if STORER.susr1=’Reusable’ where Right(storerkey,10) = orders.consigneekey, 
            get STORER.CartonGroup as carton group for cartonization
            */

            --Reusable, use consignee find carton group         
             SELECT @SKULength = SKU.Length,
                    @SKUHeight = SKU.Height,
                    @SKUWidth = SKU.Width,
                    @SKUCUBE = SKU.STDCube,
                    @SKUWeight = SKU.STDGrossWGT,
                    @SKUBusr7 = SKU.BUSR7                 
            FROM SKU SKU(NOLOCK)                   
            WHERE SKU.SKU = @SKU AND SKU.StorerKey = @c_StorerKey

            SELECT @c_CartonGroup = CartonGroup
            FROM Storer a (NOLOCK)        
            WHERE a.Type = '2' and a.StorerKey = @c_ConsigneeKey
         END
         ELSE
         BEGIN   
            --Not Reusable, use SKU find carton group         
            SELECT @c_CartonGroup = CLK.UDF01,
                   @SKULength = SKU.Length,
                   @SKUHeight = SKU.Height,
                   @SKUWidth = SKU.Width,
                   @SKUCUBE = SKU.STDCube,
                   @SKUWeight = SKU.STDGrossWGT,
                   @SKUBusr7 = SKU.BUSR7        
            FROM SKU SKU(NOLOCK) 
            JOIN CodelKup CLK (NOLOCK) ON CLK.ListName='SKUGROUP' AND CLK.Code = SKU.BUSR7         
            WHERE SKU.SKU = @SKU AND SKU.StorerKey = @c_StorerKey                 
         END
  
         --Get Hanger Cube if the item need VAs with Hanger
         IF @SKUBusr7 ='10'
         BEGIN
            SELECT @HangerCube = isnull(CLK.Long,0),
                   @HangerWeight = isnull(CLK.Notes, 0)
            FROM SKU (NOLOCK)
            JOIN CodelKup CLK (NOLOCK) ON CLK.ListName ='NKSHANGERS' and CLK.Code=SKU.Susr3 
            WHERE SKU.SKU = @SKU AND SKU.StorerKey = @c_StorerKey
            AND Code2 in (@OrderGroup+@OrderRoute)
         
            IF @HangerCube = 0 or @HangerWeight = 0
            BEGIN
               SET @b_Success = 0
               SET @n_continue = 3
               SET @n_err = "60006"
               SET @c_ErrMsg = 'Hanger Cube not available' + dbo.fnc_RTrim(@c_errmsg)
               GOTO Quit_SP
            END
         END

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
                -- @FillTolerance = isnull(FillTolerance, 0),
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
                  --  @FillTolerance = isnull(FillTolerance, 0),
                    @c_CartonType  = CartonType
            FROM Cartonization (NOLOCK) 
            WHERE Cartonizationgroup = @c_CartonGroup 
            ORDER By Cube DESC
         END
        
         IF @n_Debug =1
         BEGIN
            SELECT @Cube 'CartonCube', @MaxWeight ,@MaxCount ,@CartonLength 'CartonLength', @CartonHeight 'CartonHeight', @CartonWidth 'CartonWidth', @FillTolerance 'FillTolerance', @c_CartonType 'CartonType  '
            SELECT @SKU 'SKU', @SKUCube 'SKUCUBE', @SKULength 'SKULength', @SKUHeight 'SKUHeight', @SKUWeight 'SKUWeight', @HangerWeight 'HangerWeight', @HangerCube 'HangerCube', @OrderGroup+@OrderRoute 'OrderGroup+OrderRoute'
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
               SET @n_err = 60007
               SET @c_errmsg = 'NIKECartonization: ' + RTRIM(@c_errmsg)
               GOTO QUIT_SP
            END

                           
            --Size Can feed, put SKU into the box
            INSERT #OpenCarton (Orderkey, CartonNo, CartonType, CartonGroup,
                           CurrWeight, 
                           CurrCube, 
                           CurrCount,
                           Sts
                        ,  Pickslipno                                      --(Wan01)
                        ,  UOM                                             --(Wan01)
                           ) 
            SELECt @c_Dockey, @CartonNo, @c_CartonType, @c_CartonGroup,    --(Wan01)
            Case WHEN @SKUBusr7='10' THEN ((@SKUWeight+@HangerWeight) * @Qty) ELSE (@SKUWeight * @Qty) END,   
            Case WHEN @SKUBusr7='10' THEN ((@SKUCUBE+ @HangerCube) * @Qty) ELSE (@SKUCUBE * @Qty) END,   
            @Qty,
            '9' --Close Carton.
            ,@c_Pickslipno                                                 --(Wan01)
            ,'2'                                                           --(Wan01)
         END
         ELSE          
         BEGIN
            SET @b_Success = 0
            SET @n_err = "60008"
            SET @c_ErrMsg = "No Carton to use"                              
         END
      END
      --(Wan01) - START  
      --Insert 
      INSERT #OpenCartonDetail(CartonNo, PickDetailKey, LabelNo, SKU, PackQty, 
               Cube, 
               Weight
              , Orderkey                  --(Wan01)
               )  
    
      SELECT @CartonNo, PickDetailKey, '', SKU, Qty, 
               Case WHEN @SKUBusr7='10' THEN @SKUCUBE + @HangerCube ELSE @SKUCUBE END, 
               Case WHEN @SKUBusr7='10' THEN @SKUWeight + @HangerWeight ELSE @SKUWeight END
            , PackOrderkey                --(Wan01)  
      FROM #PickDetail 
      WHERE DropID = @c_DropID
      AND   Orderkey = @c_Orderkey
      AND   Loadkey  = @c_Loadkey

      --(Wan01) - END  
      NEXT_CartonType:

      --Set Complete the this line of record
      UPDATE #PickDetail
      SET   --LabelNo = @cLabelNo,
            --CartonGroup = @c_CartonGroup,
            --CartonType = @c_CartonType
            Sts = '9'
      WHERE DropID = @c_DropID
      AND   Orderkey = @c_Orderkey                             --(Wan01)
      AND   Loadkey  = @c_Loadkey                              --(Wan01)
      
      --(Wan01) - START
      DELETE C
      FROM CartonList C
      JOIN CartonListDetail CD ON (C.CartonKey = CD.CartonKey)
      JOIN #PickDetail PD ON (PD.PickDetailKey = CD.PickDetailKey) 
      WHERE PD.DropID   = @c_DropID
      AND   PD.Orderkey = @c_Orderkey                              
      AND   PD.Loadkey  = @c_Loadkey  
      
      DELETE CD
      FROM CartonListDetail CD 
      JOIN #PickDetail PD ON (PD.PickDetailKey = CD.PickDetailKey) 
      WHERE PD.DropID   = @c_DropID
      AND   PD.Orderkey = @c_Orderkey                              
      AND   PD.Loadkey  = @c_Loadkey  
      --(Wan01) - END
                              
      SET @c_PrevDropID = @c_DropID          
      FETCH NEXT FROM CUR_OrderList INTO @c_DropID, @c_Orderkey, @SKU, @c_StorerKey, @Qty
                                       , @c_Loadkey            --(Wan01)
   END --end of while
   CLOSE CUR_OrderList
   DEALLOCATE CUR_OrderList

   -- BL02 End
   
   --============================================================================================================

   SET @c_PickDetailKey = ''
   --SET @c_BUSR7 = ''
   --SET @c_BUSR5 = ''
   SET @CartonNo = ''

   --Start handle UOM in 6, 7
   DECLARE CUR_DynamicSQL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   
      SELECT Distinct Orderkey, Consignee , s.Notes1                                            
               ,    LoadKey                                                                        --(Wan01)
      FROM #PickDetail a
      LEFT OUTER JOIN Storer s (NOLOCK) ON s.Storerkey= a.Consignee
     
   OPEN CUR_DynamicSQL

   FETCH NEXT FROM CUR_DynamicSQL INTO @c_Orderkey, @c_ConsigneeKey, @c_Notes1                 
                                  ,    @c_LoadKey                                                  --(Wan01)
   WHILE (@@FETCH_STATUS <> -1)     
   BEGIN 
      --Reset Variable
      SET @OrderGroup = ''
      SET @OrderRoute = ''      
      SET @c_PickSlipno = ''
      SET @b_Reusable   = 0

      IF (select SUSR1 FROM Storer (NOLOCK)  WHERE StorerKey = @c_ConsigneeKey) ='Reusable'
      BEGIN
         SET @b_Reusable = 1
      END

      --(Wan01) - START
      SET @c_Zone = '3'
      IF @c_Loadkey <> '' 
      BEGIN
         SELECT @c_PickSlipno = PickheaderKey 
         FROM PICKHEADER (NOLOCK) 
         WHERE LoadKey = @c_Loadkey
         AND   ExternOrderkey = @c_Loadkey

         SET @c_Zone = '7'

         SELECT TOP 1 @OrderGroup = OrderGroup,
                  @OrderRoute = Route            
         FROM Orders (NOLOCK)
         WHERE Loadkey = @c_Loadkey

         SET @c_Dockey = @c_Loadkey
      END
      ELSE
      BEGIN
         --Gen PickSlip
         SELECT @c_PickSlipno = PickheaderKey   
         FROM PickHeader (NOLOCK)  
         WHERE Orderkey = @c_Orderkey

         SELECT @OrderGroup = OrderGroup,
                @OrderRoute = Route            
         FROM Orders (NOLOCK)
         WHERE OrderKey = @c_Orderkey

         SET @c_Dockey = @c_Orderkey
      END
      --(Wan01) - END

      --If PickSlip not found, Create Pickheader      
      IF ISNULL(@c_PickSlipno ,'') = ''  
      BEGIN  
         EXECUTE dbo.nspg_GetKey   
         'PICKSLIP',   9,   @c_Pickslipno OUTPUT,   @b_Success OUTPUT,   @n_Err OUTPUT,   @c_Errmsg OUTPUT      

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 60009   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Getkey(PICKSLIP) (ispWAVNK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            GOTO QUIT_SP
         END
        
         SELECT @c_Pickslipno = 'P'+@c_Pickslipno      

         INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, TrafficCop, Loadkey, Wavekey, Storerkey)  --(Wan01)   
         VALUES (@c_Pickslipno , @c_Loadkey, @c_Orderkey, '0', @c_Zone, '', @c_Loadkey, @c_Wavekey, @c_Storerkey)                   --(Wan01)  

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3 
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 60010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Pickheader Table (ispWAVNK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            GOTO QUIT_SP
         END
      END

      IF EXISTS (SELECT 1
                  FROM codelkup (NOLOCK) 
                  WHERE ListName = @c_Notes1 AND code2='PRECARTON')
      BEGIN
      	 --update orderdetail S --NJOW01
      	 IF EXISTS(SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'NKVASDISCT' AND Code = @c_Notes1)
      	 BEGIN      	 
            SELECT @c_SQLDYN01 = N'DECLARE CUR_OrdDetList CURSOR FAST_FORWARD READ_ONLY FOR '
                        + N' SELECT PD.PackOrderKey, PD.OrderLineNumber, ISNULL(OREF.Note1,''''), '    
                        + N'        CASE WHEN ISNULL(OD.ExtendedPrice,0)=0 THEN 0 ELSE ISNULL(OD.UnitPrice,0) / OD.ExtendedPrice END '
                        + N' FROM #PickDetail PD '
                        + N' JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = PD.PackOrderKey AND OD.OrderLineNumber = PD.OrderLineNumber ' 
                        + N' OUTER APPLY (SELECT TOP 1 ODR.Note1 FROM ORDERDETAILREF ODR (NOLOCK) WHERE ODR.Orderkey = OD.Orderkey AND ODR.OrderLineNumber = OD.OrderLineNumber AND ISNULL(ODR.Note1,'''') = N''安全扣'') AS OREF '
                        + N' WHERE PD.OrderKey = @c_Orderkey '    --NJOW02
                        --+ N' WHERE PD.UOM in(6,7) and Sts = ''0'' AND PD.OrderKey = @c_Orderkey '    
                        + N' AND PD.Loadkey = @c_Loadkey '                              
                        + N' AND PD.Consignee = @c_ConsigneeKey '                        
                        + N' GROUP BY PD.PackOrderKey, PD.OrderLineNumber, OREF.Note1, OD.ExtendedPrice, OD.UnitPrice ' +  
                        + N' ORDER BY PD.PackOrderKey, PD.OrderLineNumber '    
                        
            EXEC sp_executesql @c_SQLDYN01,
                  N'@c_Loadkey NVARCHAR(10), @c_Orderkey NVARCHAR(10), @c_Consigneekey NVARCHAR(15)', 
                  @c_Loadkey,
                  @c_Orderkey,
                  @c_Consigneekey

            OPEN CUR_OrdDetList       
                       
            FETCH NEXT FROM CUR_OrdDetList INTO @c_GetOrderkey, @c_OrderLineNumber, @c_OrderDetRefNote1, @n_Discount
            
            WHILE (@@FETCH_STATUS <> -1) AND @n_continue in(1,2)   
            BEGIN
            	 IF @c_OrderDetRefNote1 = N'安全扣' OR @n_Discount >= 0
            	 BEGIN
            	 	  UPDATE ORDERDETAIL WITH (ROWLOCK)
            	 	  SET UserDefine09 = CASE WHEN @c_OrderDetRefNote1 = N'安全扣' THEN 'SAFETYBK' ELSE 'NOSAFETYBK' END,
            	 	      UserDefine10 = CASE WHEN @n_Discount = 0 THEN '0'
            	 	                          WHEN @n_Discount > 0 AND @n_Discount <= 0.5 THEN '5'
            	 	                          WHEN @n_Discount > 0.5 THEN '10'
            	 	                          ELSE '0' END,
            	 	      TrafficCop = NULL
            	 	   WHERE Orderkey = @c_GetOrderkey
            	 	   AND OrderLineNumber = @c_OrderLineNumber
            	 	   
                   SELECT @n_err = @@ERROR
                   IF @n_err <> 0
                   BEGIN
                      SELECT @n_continue = 3
                      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 60011   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Orderdetail Table Failed. (ispWAVNK01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                   END            	 	                                      	 	
            	 END
            	 
               FETCH NEXT FROM CUR_OrdDetList INTO @c_GetOrderkey, @c_OrderLineNumber, @c_OrderDetRefNote1, @n_Discount            	 
            END
            CLOSE CUR_OrdDetList
            DEALLOCATE CUR_OrdDetList                  	                                                        
         END               
      	 --update orderdetail E
      	
         --Prepare dynamic sql
         DECLARE CUR_CODELKUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
     
            SELECT  Code, Description, Long
            FROM codelkup (NOLOCK) 
            WHERE ListName = @c_Notes1 AND code2='PRECARTON'
            ORDER BY Code            
     
         OPEN CUR_CODELKUP

         FETCH NEXT FROM CUR_CODELKUP INTO @c_Code, @c_Description, @c_TableColumnName
         SELECT @c_SQLField = '', @c_SQLWhere = '', @c_SQLGroup = '', @n_cnt = 0

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @n_cnt = @n_cnt + 1
            SET @c_TableName = LEFT(@c_TableColumnName, CharIndex('.', @c_TableColumnName) - 1)
            SET @c_ColumnName = SUBSTRING(@c_TableColumnName,
                               CharIndex('.', @c_TableColumnName) + 1, LEN(@c_TableColumnName) - CharIndex('.', @c_TableColumnName))             

            SET @c_ColumnType = ''
            SELECT @c_ColumnType = DATA_TYPE
            FROM   INFORMATION_SCHEMA.COLUMNS
            WHERE  TABLE_NAME = @c_TableName
            AND    COLUMN_NAME = @c_ColumnName

            IF ISNULL(RTRIM(@c_ColumnType), '') = ''
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 63504
               --SELECT @c_errmsg= 'NSQL'+CONVERT(char(5),@n_err)+': Invalid Column Name: ' + RTRIM(@c_TableColumnName)+ '. (ispWAVLP02)'
               --   GOTO RETURN_SP
            END

           --IF @c_ColumnType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint','text')
           --BEGIN
           -- SELECT @n_continue = 3
           -- SELECT @n_err = 63505
           -- SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Numeric/Text Column Type Is Not Allowed For Load Plan Grouping: ' + RTRIM(@c_TableColumnName)+ '. (ispWAVLP02)'
           --   GOTO RETURN_SP
           --END

            IF @c_ColumnType IN ('char', 'nvarchar', 'varchar')
            BEGIN
               SELECT @c_SQLField = @c_SQLField + ',' + RTRIM(@c_TableColumnName)
               SELECT @c_SQLWhere = @c_SQLWhere + ' AND ' + RTRIM(@c_TableColumnName) + '=' +
                     CASE WHEN @n_cnt = 1 THEN '@c_Field01'
                          WHEN @n_cnt = 2 THEN '@c_Field02'
                          WHEN @n_cnt = 3 THEN '@c_Field03'
                          WHEN @n_cnt = 4 THEN '@c_Field04'
                          WHEN @n_cnt = 5 THEN '@c_Field05'
                          WHEN @n_cnt = 6 THEN '@c_Field06'
                          WHEN @n_cnt = 7 THEN '@c_Field07'
                          WHEN @n_cnt = 8 THEN '@c_Field08'
                          WHEN @n_cnt = 9 THEN '@c_Field09'
                          WHEN @n_cnt = 10 THEN '@c_Field10' END
            END

            IF @c_ColumnType IN ('datetime')
            BEGIN
              SELECT @c_SQLField = @c_SQLField + ', CONVERT(VARCHAR(10),' + RTRIM(@c_TableColumnName) + ',112)'
              SELECT @c_SQLWhere = @c_SQLWhere + ' AND CONVERT(VARCHAR(10),' + RTRIM(@c_TableColumnName) + ',112)=' +
                     CASE WHEN @n_cnt = 1 THEN '@c_Field01'
                          WHEN @n_cnt = 2 THEN '@c_Field02'
                          WHEN @n_cnt = 3 THEN '@c_Field03'
                          WHEN @n_cnt = 4 THEN '@c_Field04'
                          WHEN @n_cnt = 5 THEN '@c_Field05'
                          WHEN @n_cnt = 6 THEN '@c_Field06'
                          WHEN @n_cnt = 7 THEN '@c_Field07'
                          WHEN @n_cnt = 8 THEN '@c_Field08'
                          WHEN @n_cnt = 9 THEN '@c_Field09'
                          WHEN @n_cnt = 10 THEN '@c_Field10' END
            END

            FETCH NEXT FROM CUR_CODELKUP INTO @c_Code, @c_Description, @c_TableColumnName
         END
         CLOSE CUR_CODELKUP
         DEALLOCATE CUR_CODELKUP
  
         SELECT @n_NoOfGroupField = @n_cnt --NJOW03

         SELECT @c_SQLGroup = @c_SQLField
         WHILE @n_cnt < 10
         BEGIN
              SET @n_cnt = @n_cnt + 1
              SELECT @c_SQLField = @c_SQLField + ','''''

              SELECT @c_SQLWhere = @c_SQLWhere + ' AND ''''=' +
                     CASE WHEN @n_cnt = 1 THEN 'ISNULL(@c_Field01,'''')'
                          WHEN @n_cnt = 2 THEN 'ISNULL(@c_Field02,'''')'
                          WHEN @n_cnt = 3 THEN 'ISNULL(@c_Field03,'''')'
                          WHEN @n_cnt = 4 THEN 'ISNULL(@c_Field04,'''')'
                          WHEN @n_cnt = 5 THEN 'ISNULL(@c_Field05,'''')'
                          WHEN @n_cnt = 6 THEN 'ISNULL(@c_Field06,'''')'
                          WHEN @n_cnt = 7 THEN 'ISNULL(@c_Field07,'''')'
                          WHEN @n_cnt = 8 THEN 'ISNULL(@c_Field08,'''')'
                          WHEN @n_cnt = 9 THEN 'ISNULL(@c_Field09,'''')'
                          WHEN @n_cnt = 10 THEN 'ISNULL(@c_Field10,'''')' END
         END

         --Create dynamic Cursor
         SELECT @c_SQLDYN01 = 'DECLARE CUR_OrderList2 CURSOR FAST_FORWARD READ_ONLY FOR '
                        + ' SELECT PD.OrderKey, PD.SKU, PD.Storerkey, sum(PD.Qty)''Qty'' ' + @c_SQLField   
                        + ',PD.Loadkey'                                                                  --(Wan01)
                        + ' FROM #PickDetail PD '
                        + ' JOIN SKU SKU(NOLOCK) ON SKU.SKU = PD.SKU AND SKU.StorerKey = PD.Storerkey '
                        + ' JOIN ORDERDETAIL (NOLOCK) ON ORDERDETAIL.OrderKey = PD.PackOrderKey AND ORDERDETAIL.OrderLineNumber = PD.OrderLineNumber ' 
                        + ' WHERE PD.UOM in(6,7) and Sts = ''0'' AND PD.OrderKey = ''' +  RTRIM(@c_Orderkey) +''''    
                        + ' AND PD.Loadkey = ''' +  RTRIM(@c_Loadkey) +''''                              --(Wan01) 
                        + ' AND PD.Consignee= ''' +  RTRIM(@c_ConsigneeKey) +''''                        --(Wan01) 
                        + ' GROUP BY PD.SKU, PD.OrderKey, PD.Storerkey, PD.Loadkey ' + @c_SQLGroup       --(Wan01)
                        + ' ORDER BY PD.Loadkey, PD.OrderKey ' + @c_SQLGroup                             --(Wan01)

         EXEC (@c_SQLDYN01)
      END
      ELSE
      BEGIN
         --Prepare the possible grouping line
         DECLARE CUR_OrderList2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

            SELECT PD.OrderKey, PD.SKU, PD.Storerkey, sum(PD.Qty)'Qty', SKU.BUSR7, SKU.BUSR5, '','','','','','','','' 
                  ,PD.Loadkey                                                                            --(Wan01)
            FROM #PickDetail PD
            JOIN SKU SKU(NOLOCK) ON SKU.SKU = PD.SKU AND SKU.StorerKey = PD.Storerkey
            WHERE UOM in(6,7) and Sts = '0' AND Orderkey = @c_Orderkey                                   --(Wan01)
            AND PD.Loadkey = @c_Loadkey                                                                  --(Wan01)
            AND PD.Consignee= @c_ConsigneeKey                                                            --(Wan01)
            GROUP BY PD.SKU, PD.OrderKey, PD.Storerkey, SKU.BUSR7, SKU.BUSR5 --, SKU.BUSR4              
                  ,  PD.Loadkey                                                                          --(Wan01)
            order by PD.Loadkey, PD.OrderKey, BUSR5, busr7                                               --(Wan01)  
      END

      OPEN CUR_OrderList2                  
      FETCH NEXT FROM CUR_OrderList2 INTO 
                                    @c_Orderkey, @SKU, @c_StorerKey, @Qty, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05
                                 ,  @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
                                 ,  @c_Loadkey                                                           --(Wan01)
      
      WHILE (@@FETCH_STATUS <> -1)     
      BEGIN 
         IF @n_Debug = 1
         BEGIN
               select 7, @c_Orderkey, @SKU, @c_StorerKey, @Qty, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,
                      @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
                     ,@c_Loadkey
         END
           
         --once change diff order Grouping
         IF @CartonNo <> '' and (@c_PrevField01 <> @c_Field01 or @c_PrevField02 <> @c_Field02 or @c_PrevField03 <> @c_Field03 or 
                                 @c_PrevField04 <> @c_Field04 or @c_PrevField05 <> @c_Field05 or @c_PrevField06 <> @c_Field06 or
                                 @c_PrevField07 <> @c_Field07 or @c_PrevField08 <> @c_Field08 or @c_PrevField09 <> @c_Field09 or
                                 @c_PrevField10 <> @c_Field10)           
         BEGIN
            --find the last carton with open status
            IF EXISTS (SELECT 1 FROM #OpenCarton WHERE CartonNo = @CartonNo and Sts <>'9' )
            BEGIN

               --RESET Variable
               SET @Cube          =0
               SET @MaxWeight     =0
               SET @MaxCount      =0
               SET @CartonLength  =0
               SET @CartonHeight  =0
               SET @CartonWidth   =0
               SET @FillTolerance =0
               SET @CurrCube = 0
               SET @c_CartonType  =''

               SELECT @CurrCube = CurrCube FROM #OpenCarton WHERE CartonNo = @CartonNo
            
               --Manage Last Carton for this group
               SELECT top 1   @Cube          = Cube,
                              @MaxWeight     = MaxWeight,    
                              @MaxCount      = MaxCount,   
                              @CartonLength  = CartonLength, 
                              @CartonHeight  = CartonHeight,
                              @CartonWidth   = CartonWidth, 
                            --  @FillTolerance = isnull(FillTolerance, 0),
                              @c_CartonType  = CartonType
               FROM Cartonization (NOLOCK) 
               WHERE Cartonizationgroup = @c_CartonGroup AND Cube >= @CurrCube
               ORDER BY Cube 

               --Check Cube can fit in the smaller carton or not
               IF (@c_CartonType<>'')
               BEGIN
                  -- Change to smaller carton and closed it
                  UPDATE #OpenCarton
                  SET CartonType = @c_CartonType,
                        STS = '9'
                  WHERE CartonNo = @CartonNo                                                      
               END 
               ELSE
               BEGIN
                  --If no suitable case close with current cartontype before next grouping
                  UPDATE #OpenCarton
                  SET Sts = '9'
                  WHERE CartonNo = @CartonNo and Sts = '0'
               END
            END
            SET @CartonNo = ''
         END

         SET @SKULength = 0.00
         SET @SKUHeight = 0.00
         SET @SKUWidth  = 0.00
         SET @SKUCUBE   = 0.00
         SET @SKUWeight = 0.00
         SET @SKUBusr7  =''
         SET @c_SKUSUSR3= ''
         SELECT   @SKULength = SKU.Length,
                  @SKUHeight = SKU.Height,
                  @SKUWidth = SKU.Width,
                  @SKUCUBE = SKU.STDCube,
                  @SKUWeight = SKU.weight,
                  @SKUBusr7  = SKU.BUSR7
               ,  @c_SKUSUSR3= SKU.Susr3  
         FROM SKU SKU(NOLOCK)
         WHERE SKU.SKU = @SKU AND SKU.StorerKey = @c_StorerKey                                       

         --SELECT @c_CartonGroup = CK.Long
         --FROM SKU (NOLOCK)
         --JOIN codelkup ck (NOLOCK) ON CK.Code2 = 'CARTONGROUP' AND ListName = @c_Notes1 ck.Code = SKU.BUSR7
         --WHERE SKU = @SKU AND SKU.StorerKey = @c_StorerKey

         SET @c_CartonGroup = ''

         IF ISNULL(RTRIM(@c_Notes1),'') <> '' 
         BEGIN  
            SELECT @c_CartonGroup = CK.Long 
            FROM codelkup ck (NOLOCK)
            WHERE CK.Code2 = 'CARTONGROUP' AND ck.ListName = @c_Notes1 AND ck.Code = @SKUBusr7
         END

         IF isnull(@c_CartonGroup,'')=''
         BEGIN
            --Get SKU Info and Carton Group
            --IF (select SUSR1 FROM Storer (NOLOCK)  WHERE StorerKey = @c_ConsigneeKey) ='Reusable'
            IF @b_Reusable = 1
            BEGIN
               /*
               -  if STORER.susr1=’Reusable’ where Right(storerkey,10) = orders.consigneekey, 
                  get STORER.CartonGroup as carton group for cartonization
               */

               ------Reusable, use consignee find carton group         
               ----   SELECT @SKULength = SKU.Length,
               ----         @SKUHeight = SKU.Height,
               ----         @SKUWidth = SKU.Width,
               ----         @SKUCUBE = SKU.STDCube,
               ----         @SKUWeight = SKU.weight,
               ----         @SKUBusr7 = SKU.BUSR7                 
               ----FROM SKU SKU(NOLOCK)                   
               ----WHERE SKU.SKU = @SKU AND SKU.StorerKey = @c_StorerKey

               SELECT @c_CartonGroup = CartonGroup
               FROM Storer a (NOLOCK)        
               WHERE a.Type = '2' and a.StorerKey = @c_ConsigneeKey
            END
            ELSE
            BEGIN   
               --Not Reusable, use SKU find carton group         
               --SELECT @c_CartonGroup   = CLK.UDF01,
               --       @SKULength       = SKU.Length,
               --       @SKUHeight       = SKU.Height,
               --       @SKUWidth        = SKU.Width,
               --       @SKUCUBE         = SKU.STDCube,
               --       @SKUWeight       = SKU.weight,
               --       @SKUBusr7        = SKU.BUSR7                
               --FROM SKU SKU(NOLOCK) 
               --JOIN CodelKup CLK (NOLOCK) ON CLK.ListName='SKUGROUP' AND CLK.Code = SKU.BUSR7         
               --WHERE SKU.SKU = @SKU AND SKU.StorerKey = @c_StorerKey                 

               SELECT @c_CartonGroup = CLK.UDF01
               FROM CodelKup CLK (NOLOCK)
               WHERE CLK.ListName='SKUGROUP' AND CLK.Code = @SKUBusr7
            END
         END

         --If Cartongroup Not found
         IF isnull(@c_CartonGroup,'')=''
         BEGIN
            SET @b_Success = 0
            SET @n_continue = 3
            SET @n_err = '60011'
            SET @c_ErrMsg = 'Cartongroup not available' + dbo.fnc_RTrim(@c_errmsg)
            GOTO Quit_SP
         END

         IF @n_Debug =2
         BEGIN
            select @c_CartonGroup, @SKULength, @SKUHeight, @SKUWidth, @SKUCUBE'SKUCUBE', @SKUWeight'SKUWeight', @SKUBusr7 'SKUBusr7'
                  ,@CurrCube 'CurrCube', @CurrWeight 'CurrWeight '
         END

         --Get Hanger Cube if the item need VAs with Hanger
         IF @SKUBusr7 ='10'
         BEGIN
            --SELECT @HangerCube = isnull(CLK.Long,0),
            --       @HangerWeight = isnull(CLK.Notes, 0)
            --FROM SKU (NOLOCK)
            --JOIN CodelKup CLK (NOLOCK) ON CLK.ListName ='NKSHANGERS' and CLK.Code=SKU.Susr3 
            --WHERE SKU.SKU = @SKU AND SKU.StorerKey = @c_StorerKey
            --AND Code2 in (@OrderGroup+@OrderRoute)

            SELECT @HangerCube = isnull(CLK.Long,0),
                   @HangerWeight = isnull(CLK.Notes, 0)
            FROM CodelKup CLK (NOLOCK) 
            WHERE CLK.ListName ='NKSHANGERS' and CLK.Code=@c_SKUSUSR3
            AND CLK.Code2 in (@OrderGroup+@OrderRoute)

            IF isnull(@HangerCube,0) = 0 or isnull(@HangerWeight,0) = 0
            BEGIN
               SET @b_Success = 0
               SET @n_continue = 3
               SET @n_err = '60012'
               SET @c_ErrMsg = 'Hanger Cube not available' + dbo.fnc_RTrim(@c_errmsg)
               GOTO Quit_SP
            END
         END

         --Reset To Default value
         SET @Cube            = ''
         SET @MaxWeight       = ''
         SET @MaxCount        = ''
         SET @CartonLength    = ''
         SET @CartonHeight    = ''
         SET @CartonWidth     = ''
         SET @FillTolerance   = ''
         SET @c_CartonType    = ''

         SELECT TOP 1 @Cube         = Cube,
                     @MaxWeight     = MaxWeight,    
                     @MaxCount      = MaxCount,   
                     @CartonLength  = CartonLength, 
                     @CartonHeight  = CartonHeight,
                     @CartonWidth   = CartonWidth, 
                     @c_CartonType  = CartonType
         FROM Cartonization (NOLOCK) 
         WHERE Cartonizationgroup = @c_CartonGroup 
         ORDER BY Cube DESC

         --base on grouping line get the related PickDetail
         DECLARE CUR_OrderList3 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Qty, PickDetailKey, PackOrderkey                                                   --(Wan01)
            FROM #PickDetail PD
            WHERE OrderKey = @c_Orderkey and SKU = @SKU and StorerKey = @c_StorerKey AND Sts ='0'     --(Wan01)
            AND   Loadkey  = @c_Loadkey                                                               --(Wan01)

         OPEN CUR_OrderList3
         FETCH NEXT FROM CUR_OrderList3 INTO @PickDetailQty, @c_PickDetailKey, @c_PackOrderkey        --(Wan01)

         WHILE (@@FETCH_STATUS <> -1)     
         BEGIN   
            SET @CntCount        = 1
            -----------------------------------------------
            -- Get Largest Carton Size and open one Carton
            -----------------------------------------------
            WHILE @CntCount <= @PickDetailQty
            BEGIN

               --Check Any Open Carton for this Order SKU 
               IF EXISTS (SELECT 1 FROM #OpenCarton WHERE Sts = 0 and PickSlipNo = @c_PickSlipno and CartonType = @c_CartonType AND UOM = '7')--(Wan01)
               BEGIN
                  --SELECT 'Got Open carton, Get The Current Carton Info'

                  SELECT @CartonNo = CartonNo,
                         @CurrWeight = CurrWeight, 
                         @CurrCube = CurrCube, 
                         @CurrCount = CurrCount
                  FROM #OpenCarton 
                  WHERE Sts = 0 and PickSlipNo = @c_PickSlipno and CartonType = @c_CartonType      --(Wan01)
                  AND   UOM = '7'                                                                  --(Wan01)
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
                     SET @n_err = '60013'
                     SET @c_ErrMsg = 'nspg_getkey ' + dbo.fnc_RTrim(@c_errmsg)
                     GOTO Quit_SP
                  END

                  SET @CurrWeight =0
                  SET @CurrCube = 0
                  SET @CurrCount =0 

                  INSERT #OpenCarton (OrderKey, CartonNo, CartonType, CartonGroup, CurrWeight, CurrCube, CurrCount, Sts
                                     ,PickSlipNo, UOM                                               --(Wan01)
                                     ) 
                  SELECt @c_Dockey, @CartonNo, @c_CartonType, @c_CartonGroup, @CurrWeight, @CurrCube, @CurrCount, '0'--(Wan01)
                                     ,@c_PickSlipNo, '7'                                            --(Wan01) 
               END

               IF @n_Debug =3 --and @c_Orderkey = '0007793213'
               BEGIN
                  SELECT @SKUBusr7'BUSR7', @c_CartonGroup '@c_CartonGroup',@c_CartonType 'CartonType', @Cube 'CartonCube'
                       , @MaxWeight ,@MaxCount ,@CartonLength 'CartonLength', @CartonHeight 'CartonHeight'
                       , @CartonWidth 'CartonWidth'
                  SELECT @SKU 'SKU', @SKUCube 'SKUCUBE', @SKULength 'SKULength', @SKUHeight 'SKUHeight', @SKUWeight 'SKUWeight'
                       , @HangerWeight 'HangerWeight', @HangerCube 'HangerCube', @OrderGroup+@OrderRoute 'OrderGroup+OrderRoute'
                       , @CurrCube 'CurrCube' 
                       , @CartonNo 'CartonNo', @cLabelNo 'LabelNo'
                       , @c_Orderkey 'Orderkey'
               END     

               SET @n_TotalCube = (@SKUCUBE+ @CurrCube)
               IF @SKUBusr7='10'
               BEGIN
                  SET @n_TotalCube = @SKUCUBE + @HangerCube + @CurrCube
               END

               IF @n_TotalCube <= @Cube
               BEGIN
                  --insert item Into CARTON            
                  INSERT #OpenCartonDetail(CartonNo, PickDetailKey, LabelNo, SKU, PackQty, 
                           Cube, Weight
                        ,Orderkey )                                        --(Wan01)
                  SELECT @CartonNo, @c_PickDetailKey, '', @SKU, 1, 
                           Case WHEN @SKUBusr7='10' THEN @SKUCUBE + @HangerCube ELSE @SKUCUBE END, 
                           Case WHEN @SKUBusr7='10' THEN @SKUWeight + @HangerWeight ELSE @SKUWeight END 
                        ,@c_PackOrderkey                                   --(Wan01)                         
               END
               ELSE
               BEGIN
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
            WHERE PickDetailKey = @c_PickDetailKey

            --(Wan01) - START
            DELETE C
            FROM CartonList C
            JOIN CartonListDetail CD ON (C.CartonKey = CD.CartonKey)
            WHERE CD.PickDetailKey = @c_PickDetailKey                              
            
            DELETE CD
            FROM CartonListDetail CD 
            WHERE CD.PickDetailKey = @c_PickDetailKey                              
            --(Wan01) - END

            FETCH NEXT FROM CUR_OrderList3 INTO @PickDetailQty, @c_PickDetailKey, @c_PackOrderkey        --(Wan01)
         END --end of while
         CLOSE CUR_OrderList3
         DEALLOCATE CUR_OrderList3

         SELECT @c_PrevField01 = @c_Field01,@c_PrevField02 = @c_Field02,@c_PrevField03 = @c_Field03
               ,@c_PrevField04 = @c_Field04,@c_PrevField05 = @c_Field05,@c_PrevField06 = @c_Field06
               ,@c_PrevField07 = @c_Field07,@c_PrevField08 = @c_Field08,@c_PrevField09 = @c_Field09
               ,@c_PrevField10 = @c_Field10

         --DELETE CartonList WHERE CartonKey IN (select CartonKey FROM CartonListDetail (NOLOCK) WHERE Orderkey = @c_Orderkey)
         --DELETE CartonListDetail WHERE OrderKey = @c_Orderkey                       

         FETCH NEXT FROM CUR_OrderList2 INTO @c_Orderkey, @SKU, @c_StorerKey, @Qty, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,
                                 @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
                              ,  @c_Loadkey                                                        --(Wan01)

      END --end of while
      CLOSE CUR_OrderList2
      DEALLOCATE CUR_OrderList2

      FETCH NEXT FROM CUR_DynamicSQL INTO   @c_PackOrderkey, @c_ConsigneeKey, @c_Notes1            --(Wan01)
                                       ,    @c_LoadKey                                             --(Wan01)

   END --end of while
   CLOSE CUR_DynamicSQL
   DEALLOCATE CUR_DynamicSQL

   --Manage Last Carton 
   WHILE 1=1
   BEGIN
      SET @CartonNo = ''

      --find the last carton with open status
      SELECT @CartonNo = CartonNo FROM #OpenCarton WHERE Sts <>'9' 

      IF @CartonNo <> ''
      BEGIN
         --RESET Variable
         SET @Cube          =0
         SET @MaxWeight     =0
         SET @MaxCount      =0
         SET @CartonLength  =0
         SET @CartonHeight  =0
         SET @CartonWidth   =0
         SET @FillTolerance =0
         SET @CurrCube = 0
         SET @c_CartonType  =''

         SELECT @CurrCube = CurrCube, @c_CartonGroup = CartonGroup FROM #OpenCarton WHERE CartonNo = @CartonNo
            
         --Manage Last Carton for this group
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
            -- Change to smaller carton and closed it
            UPDATE #OpenCarton
            SET CartonType = @c_CartonType,
                  STS = '9'
            WHERE CartonNo = @CartonNo                                                      
         END 
         ELSE
         BEGIN
            --If no suitable case close with current cartontype before next grouping
            UPDATE #OpenCarton
            SET Sts = '9'
            WHERE CartonNo = @CartonNo and Sts = '0'
         END                                               
      END
      ELSE 
      BEGIN
         BREAK 
      END
   END --END While

   --Re-Sequence The SEQNO, and Gen LabelNo for every carton
   DECLARE @PrevOrderkey NVARCHAR(15)
   SET @PrevOrderkey = ''

   DECLARE CUR_TempCartonList CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT CartonNo, PickSlipNo                                          --(Wan01)
      FROM #OpenCarton
      ORDER BY PickSlipNo, CartonNo                                        --(Wan01)

   OPEN CUR_TempCartonList
   FETCH NEXT FROM CUR_TempCartonList INTO @CartonNo, @c_PickSlipNo        --(Wan01)
      
   WHILE (@@FETCH_STATUS <> -1)     
   BEGIN   

      --Reset counter when different Orderkey
      IF @c_PrevPickSlipno <> @c_PickSlipno                                --(Wan01)
      BEGIN
         SET @CntCount = 1
         SET @c_PrevPickSlipno = @c_PickSlipno                             --(Wan01)
      END
     
      UPDATE #OpenCarton
      SET SeqNo = @CntCount
      WHERE CartonNo = @CartonNo
      
      --Gen Label                   
      EXECUTE isp_GLBL08
               @c_PickSlipNo = @c_PickSlipno,       --(Wan01)
               @n_CartonNo   = 0,
               @c_LabelNo    = @cLabelNo   OUTPUT   --(Wan01) 

      IF @cLabelNo = ''
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60017
         SET @c_errmsg = 'isp_GLBL08: ' + RTRIM(@c_errmsg)
         GOTO QUIT_SP
      END

      UPDATE #OpenCartonDetail
      SET LabelNo = @cLabelNo
      WHERE CartonNo = @CartonNo

      SELECT @CntCount = @CntCount + 1

      FETCH NEXT FROM CUR_TempCartonList INTO @CartonNo, @c_PickSlipNo        --(Wan01)

   END --end of while

   CLOSE CUR_TempCartonList
   DEALLOCATE CUR_TempCartonList

   
    
   -------------------
   Begin Transaction
   -------------------
   DECLARE @CntCount2 INT   
   --====================================================================================
   -- Split PickDetail
   --====================================================================================
   DECLARE CUR_SplitPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickDetailKey, count(LabelNo)
      FROM #OpenCartonDetail         
      GROUP BY PickDetailKey
      HAVING count(LabelNo) > 1
      ORDER BY PickDetailKey

   OPEN CUR_SplitPickDetail
   FETCH NEXT FROM CUR_SplitPickDetail INTO @c_PickDetailKey, @CntCount
      
   WHILE (@@FETCH_STATUS <> -1)     
   BEGIN   
      DECLARE CUR_SubSplitPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   
      SELECT LabelNo, Sum(PackQty) 'PackQty'
      FROM #OpenCartonDetail 
      WHERE PickDetailKey = @c_PickDetailKey
      GROUP BY PICKDETAILKey, LabelNo   
     
      OPEN CUR_SubSplitPickDetail
      FETCH NEXT FROM CUR_SubSplitPickDetail INTO @cLabelNo, @Qty
   
      WHILE (@@FETCH_STATUS <> -1)     
      BEGIN
                                                                        
         IF (select  Qty - @Qty from PICKDETAIL (NOLOCK) WHERE PickdetailKey = @c_PickDetailKey) > 0
         BEGIN

            --Get New PickDetailKey                 
            EXECUTE nspg_GetKey
               'PICKDETAILKEY',
               10,
               @c_NewPickDetailKey OUTPUT,
               @b_success OUTPUT,
               @n_err OUTPUT,
               @c_errmsg OUTPUT

            IF NOT @b_success = 1
            BEGIN
         
              SET @b_Success = 0
               SET @n_continue = 3
               SET @n_err = "60018"
               SET @c_ErrMsg = 'nspg_getkey ' + dbo.fnc_RTrim(@c_errmsg)
               GOTO Quit_SP

            END
         
            --select OD.* FROM OrderDetail OD (NOLOCK)
            --JOIN PICKDETAIL PD (NOLOCK) on  PickdetailKey = @c_PickDetailKey and OD.orderkey = PD.OrderKey and PD.OrderLineNumber = OD.OrderLineNumber

             --Minus the Original PickDetail Line
            UPDATE PICKDETAIL
            SET Qty = Qty - @Qty,
                UOMQTY = CASE UOM WHEN '7' THEN Qty - @Qty ELSE UOMQty END
                --TrafficCop = NULL
            WHERE PickdetailKey = @c_PickDetailKey
        
            --Insert New PickDetail split from original PickDetail
            INSERT PICKDETAIL
            (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
            Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
            DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
            ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, EffectiveDate, OptimizeCop, 
            ShipFlag, PickSlipNo, Taskdetailkey, TaskManagerReasonkey, Notes )
            SELECT @c_NewPickDetailKey, '', PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                     Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '7' THEN @Qty ELSE UOMQty END, @Qty, QtyMoved, Status,
                     DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                     ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                     WaveKey, EffectiveDate, null, ShipFlag, PickSlipNo, Taskdetailkey, TaskManagerReasonkey, Notes
            FROM PICKDETAIL (NOLOCK)
            WHERE PickdetailKey = @c_PickDetailKey

            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 60019   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispWAVNK01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               GOTO QUIT_SP
            END
          
            --Update New PickDetailKey to OpenCartonDetail 
            UPDATE #OpenCartonDetail
            SET PickDetailKey = @c_NewPickDetailKey
            WHERE LabelNo = @cLabelNo AND PickdetailKey = @c_PickDetailKey
         END
         ELSE
         BEGIN
            IF @n_Debug = 99
            BEGIN
                  SELECT 'Split Qty more than PickDetail Quantity:' + 'PickDetailKey: ' + @c_PickDetailKey
            END 
         END
                                               
         FETCH NEXT FROM CUR_SubSplitPickDetail INTO @cLabelNo, @Qty

      END --end of while

      CLOSE CUR_SubSplitPickDetail
      DEALLOCATE CUR_SubSplitPickDetail
     
      FETCH NEXT FROM CUR_SplitPickDetail INTO @c_PickDetailKey, @CntCount 

   END --end of while

   CLOSE CUR_SplitPickDetail
   DEALLOCATE CUR_SplitPickDetail
      
QUIT_SP:
   IF @b_Success =1 --When Success
   BEGIN                                 

      --insert CartonList
      INSERT CartonList (CartonKey, SeqNo, CartonType,CurrWeight,CurrCube,CurrCount,Status)
      SELECT CartonNo, SeqNo, Cartontype, CurrWeight, CurrCube, CurrCount, Sts  
      FROM #OpenCarton

      ----Insert Cartonization Result   
      INSERT CartonListDetail (CartonKey, SKU, Qty, OrderKey, PickDetailKey, LabelNo)
      SELECT a.CartonNo, SKU, Sum(PackQty), a.OrderKey, a.PickDetailKey, a.LabelNo     --(Wan01)
      FROM #OpenCartonDetail a
      JOIN #OpenCarton b on b.CartonNo = a.CartonNo
      GROUP BY a.CartonNo, a.PickDetailKey, a.LabelNo, a.SKU,  a.OrderKey              --(Wan01)
      
      
      if @n_Debug = 99
      BEGIN
         select * from #OpenCarton

         select CartonNo, PickDetailKey, LabelNo, SKU, Sum(PackQty)'PackQty', sum(Cube)'SumCube', sum (Weight) 'SumWeight'
         from #OpenCartonDetail         
         group by CartonNo, PickDetailKey, LabelNo, SKU

      
         SELECT PickDetailKey, count(LabelNo)
         FROM #OpenCartonDetail         
         GROUP BY PickDetailKey
         HAVING count(LabelNo) > 1
      END

     ----Update caseid
     UPDATE a
     Set a.CaseID = b.LabelNo        
     FROM PickDetail a (ROWLOCK)
     JOIN #OpenCartonDetail b on b.PickDetailKey = a.PickDetailKey

   END

   --Clear Cursor if cursor still exists   
   IF CURSOR_STATUS('GLOBAL' , 'CUR_OrderList') in (0 , 1)          
   BEGIN          
      CLOSE CUR_OrderList          
      DEALLOCATE CUR_OrderList          
   END

   IF CURSOR_STATUS('GLOBAL' , 'CUR_OrderList2') in (0 , 1)          
   BEGIN          
      CLOSE CUR_OrderList2          
      DEALLOCATE CUR_OrderList2          
   END

   IF CURSOR_STATUS('GLOBAL' , 'CUR_OrderList3') in (0 , 1)          
   BEGIN          
      CLOSE CUR_OrderList3
      DEALLOCATE CUR_OrderList3
   END

   IF CURSOR_STATUS('GLOBAL' , 'CUR_TempCartonList') in (0 , 1)          
   BEGIN          
      CLOSE CUR_TempCartonList
      DEALLOCATE CUR_TempCartonList
   END

   IF CURSOR_STATUS('GLOBAL' , 'CUR_SplitPickDetail') in (0 , 1)          
   BEGIN          
      CLOSE CUR_SplitPickDetail
      DEALLOCATE CUR_SplitPickDetail
   END  

   IF CURSOR_STATUS('GLOBAL' , 'CUR_DynamicSQL') in (0 , 1)          
   BEGIN          
      CLOSE CUR_DynamicSQL
      DEALLOCATE CUR_DynamicSQL
   END  

   IF CURSOR_STATUS('GLOBAL' , 'CheckCube_Cursor') in (0 , 1)          
   BEGIN          
      CLOSE CheckCube_Cursor
      DEALLOCATE CheckCube_Cursor
   END

   -- DROP TEMP TABLE
   IF OBJECT_ID('tempdb..#OpenCarton','u') IS NOT NULL
   DROP TABLE #OpenCarton;

   IF OBJECT_ID('tempdb..#OpenCartonDetail','u') IS NOT NULL
   DROP TABLE #OpenCartonDetail;

   IF OBJECT_ID('tempdb..#PickDetail','u') IS NOT NULL
   DROP TABLE #PickDetail;
           
   IF OBJECT_ID('tempdb..#Temp','u') IS NOT NULL
   DROP TABLE #Temp;

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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispWAVNK01'    
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