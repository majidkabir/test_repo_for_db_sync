SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* SP: ispWAVPK05                                                       */
/* Creation Date: 12 Nov 2018                                           */
/* Copyright: IDS                                                       */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-6788 - [CN] NIKECN PreCartonization Logic               */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* RDTMsg :                                                             */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2018-12-12  Wan01    1.1   Fixed Same Carton creat for 2 load        */
/* 2018-12-14  Wan02    1.1   CR Last carton By Site+PickZone OR Pickslip*/
/* 2018-12-14  Wan03    1.1   Fixed add order by                        */
/* 2018-12-19  Wan04    1.1   Fixed Update RatioDivident                */
/* 2019-01-02  Wan05    1.2   WMS-7407 - [CN] NIKECN PreCartonization   */
/*                            Logic_CR                                  */
/* 2019-02-11  Wan06    1.2   WMS-7407 - [CN] NIKECN PreCartonization   */
/*                            Logic_CR - Additional CR                  */
/* 2019-02-21  Wan07    1.3   Fixed Floor issue, VAS issue              */
/* 2019-10-29  WLChooi  1.4   WMS-11017 - Update Weight & Cube into     */
/*                                        PackInfo table (WL01)         */
/* 2020-1-17   AL01     1.5   Bug fix, initialize @n_TotalRatio         */
/* 2022-08-31  BeeTin   1.6   JSM-92837-Fix duplicate  primary key      */ 
/************************************************************************/
CREATE PROC [dbo].[ispWAVPK05]
(
    @c_WaveKey       NVARCHAR(20)
   ,@b_Success       INT            OUTPUT
   ,@n_err           INT            OUTPUT
   ,@c_ErrMsg        NVARCHAR(250)  OUTPUT  
   ,@c_Source        NVARCHAR(10) = 'WP'    
)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_StartTCnt             INT
         , @n_Continue              INT = 1
         , @b_debug                 BIT = 0

   DECLARE @n_VAS                   INT = 0           --(Wan05) 
         , @n_SplitPickDetail       BIT

         , @n_Cnt                   INT
         
         , @n_CartonCube_X16        FLOAT
         , @n_CartonCube_X18        FLOAT     
         , @n_PackFactor            FLOAT
         , @n_CartonCube            FLOAT
                
         , @c_Facility              NVARCHAR(5)                                                                           
                                                         
         , @c_DocumentKey           NVARCHAR(10)
         , @c_Loadkey               NVARCHAR(10)
         , @c_PickZone              NVARCHAR(10)
         , @c_Site                  NVARCHAR(30)
         , @c_Storerkey             NVARCHAR(15)
         , @c_Storerkey_Prev        NVARCHAR(15)
         , @c_Sku                   NVARCHAR(20)
         , @c_Sku_Prev              NVARCHAR(20)
         , @c_Division              NVARCHAR(30)   -- SKU.BUSR7
         , @c_Material              NVARCHAR(10)   -- SKU.ItemClass
         , @c_SkuCGD                NVARCHAR(18)   -- SKU.SUSR3
         , @c_CartonType            NVARCHAR(10)
         , @c_CartonGroup           NVARCHAR(10)
         , @c_Orderkey              NVARCHAR(10)
         , @c_OrderLineNumber       NVARCHAR(5)

         , @n_StdCube               FLOAT
         , @n_VASItemsCube          FLOAT
         , @n_SkuPackCube           FLOAT
         , @n_SkuQtyPerCTN          INT
         , @n_NoOfCTN               INT
         , @n_NoOfFullCTN           INT
         , @c_VasListName           NVARCHAR(10)

         , @n_RowID                 INT
         , @n_NewRowID              INT
         , @n_CartonID              INT
         , @n_LastCartonID          INT
         , @n_2LastCartonID         INT
         , @c_LastCartonBy          NVARCHAR(45)   --(Wan02)   
         
         , @n_Qty                   INT
         , @n_RemainingPerCTN       INT
         , @n_SplitQty              INT
         , @n_InsertPackQty         INT
         , @n_RatioQty              INT = 0        --(Wan04)

         , @c_PickDetailKey         NVARCHAR(10)
         , @c_NewPickDetailkey      NVARCHAR(10)

         , @n_RatioDivident         FLOAT
         , @n_RatioDivisor          FLOAT
         , @n_SkuRatio              FLOAT
         , @n_TotalRatio            FLOAT

         , @n_CartonNo              INT
         , @c_PickSlipNo            NVARCHAR(10)
         , @c_LabelNo               NVARCHAR(20)
         , @c_CartonKey             NVARCHAR(10)
         , @c_RefNo2                NVARCHAR(30)

         , @c_NIKEPackByCGD            NVARCHAR(30)
         , @c_LPGenPackFromPicked      NVARCHAR(30)
         , @c_WaveGenPackFromPicked_SP NVARCHAR(30)

         --WL01
         , @n_CtnWeight             FLOAT
         , @n_CtnCube               FLOAT


         , @n_PackQtyIndicator      INT            --(Wan05)
         , @n_PackQtyLimit          INT            --(Wan05)
         , @n_Add2CartonID          INT            --(Wan05)
         , @n_Add2RowID             INT            --(Wan05)
         , @n_PackCube              FLOAT          --(Wan05)
         , @n_TotalPackCube         FLOAT          --(Wan05)
         , @c_Status                NVARCHAR(10)   --(Wan05)

   DECLARE @CUR_PD                  CURSOR
         , @CUR_SKUCTN              CURSOR
         , @CUR_MIXCTN              CURSOR

   --(Wan05) - START
   DECLARE @TLASTCTN TABLE
      (
         RowID             INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
      ,  Loadkey           NVARCHAR(10)   NOT NULL
      ,  PickZone          NVARCHAR(10)   NOT NULL
      ,  Division          NVARCHAR(30)   NOT NULL
      ,  Material          NVARCHAR(10)   NOT NULL
      ,  SkuCGD            NVARCHAR(18)   NOT NULL
      ,  VAS               INT            NOT NULL
      --,  [Site]            INT            NOT NULL
      ,  CartonGroup       NVARCHAR(10)   NOT NULL   
      ,  CartonID          INT            NOT NULL 
      ,  TotalRatio        FLOAT          NOT NULL DEFAULT(0.00)
      ,  TotalPackCube     FLOAT          NOT NULL DEFAULT(0.00)
      ,  [Status]          NVARCHAR(10)   NOT NULL DEFAULT('0')
     )
   --(Wan05) - END

   SET @b_success = 1 --Preset to success
   SET @n_StartTCnt=@@TRANCOUNT

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   DECLARE @tORDERS TABLE  
   (  OrderKey          NVARCHAR(10)   NOT NULL
   ,  Loadkey           NVARCHAR(10)   NOT NULL
   ,  Facility          NVARCHAR(5)    NOT NULL
   ,  Storerkey         NVARCHAR(15)   NOT NULL
   PRIMARY KEY CLUSTERED (OrderKey)
   )

   SET @c_DocumentKey = @c_Wavekey
   IF @c_Source = 'WP' 
   BEGIN
      INSERT INTO @tORDERS
      SELECT WD.Orderkey
            ,OH.Loadkey
            ,OH.Facility
            ,OH.Storerkey
      FROM WAVEDETAIL WD WITH (NOLOCK)
      JOIN ORDERS     OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
      WHERE WD.Wavekey = @c_DocumentKey
   END
   ELSE
   BEGIN
      INSERT INTO @tORDERS
      SELECT LPD.Orderkey
            ,OH.Loadkey
            ,OH.Facility
            ,OH.Storerkey
      FROM LOADPLANDETAIL LPD WITH (NOLOCK)
      JOIN ORDERS         OH WITH (NOLOCK) ON LPD.Orderkey = OH.Orderkey
      WHERE LPD.Loadkey = @c_DocumentKey

      SET @c_Wavekey = ''                    --(Wan06)
   END

   -- IF CaseId exists in PickDetil, end process.
   IF EXISTS ( SELECT 1
               FROM @tORDERS t
               JOIN PICKDETAIL PD  WITH (NOLOCK) ON PD.OrderKey = t.OrderKey
               WHERE PD.CaseId <> '' AND PD.CaseID IS NOT NULL
            )
   BEGIN
      SET @n_continue = 3  
      SET @n_err = 60010
      SET @c_ErrMsg = 'Case ID already got data, cannot run pre-cartonization. (ispWAVPK05)'
      GOTO QUIT_SP
   END

   IF EXISTS ( SELECT 1
               FROM @tORDERS t
               JOIN PICKHEADER P  WITH (NOLOCK) ON  t.Loadkey = P.ExternOrderkey
                                                AND t.Loadkey = P.LoadKey
               JOIN PACKHEADER PK WITH (NOLOCK) ON  P.PickHeaderKey = PK.PackStatus
               WHERE PK.Status = '9'
            )
   BEGIN
      SET @n_continue = 3  
      SET @n_err = 60020
      SET @c_ErrMsg = 'Laod had been Pack Confirm, cannot run pre-cartonization. (ispWAVPK05)'
      GOTO QUIT_SP
   END
   
   SELECT TOP 1 
            @c_Facility = t.Facility
         ,  @c_Storerkey= t.Storerkey
   FROM @tORDERS t

   EXEC nspGetRight
      @c_Facility = @c_Facility
   ,  @c_Storerkey= @c_Storerkey
   ,  @c_Sku = ''
   ,  @c_Configkey= 'LPGENPACKFROMPICKED'
   ,  @b_Success  = @b_Success               OUTPUT
   ,  @c_Authority= @c_LPGenPackFromPicked   OUTPUT
   ,  @n_Err      = @n_Err                   OUTPUT
   ,  @c_ErrMsg   = @c_ErrMsg                OUTPUT

   IF  @b_Success <> 1
   BEGIN
      SET @n_continue = 3  
      SET @n_err = 60030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ERROR Executing nspGetRight - LPGenPackFromPicked. (ispWAVPK05)' 
      GOTO QUIT_SP
   END        
       
   IF @c_LPGenPackFromPicked = 'ispWAVPK05' AND @c_Source = ''
   BEGIN
      SET @n_continue = 3  
      SET @n_err = 60040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Storer is only permitted to generate PackFromPick at Loadplan. (ispWAVPK05)' 
      GOTO QUIT_SP
   END

   EXEC nspGetRight
      @c_Facility = @c_Facility
   ,  @c_Storerkey= @c_Storerkey
   ,  @c_Sku = ''
   ,  @c_Configkey= 'WAVGENPACKFROMPICKED_SP'
   ,  @b_Success  = @b_Success                  OUTPUT
   ,  @c_Authority= @c_WaveGenPackFromPicked_SP OUTPUT
   ,  @n_Err      = @n_Err                      OUTPUT
   ,  @c_ErrMsg   = @c_ErrMsg                   OUTPUT

   IF  @b_Success <> 1
   BEGIN
      SET @n_continue = 3  
      SET @n_err = 60050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ERROR Executing nspGetRight - WaveGenPackFromPicked_SP. (ispWAVPK05)' 
      GOTO QUIT_SP
   END        
       
   IF @c_WaveGenPackFromPicked_SP = 'ispWAVPK05' AND @c_Source = 'LP'
   BEGIN
      SET @n_continue = 3  
      SET @n_err = 60060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Storer is only permitted to generate PackFromPick at Wave Screen. (ispWAVPK05)' 
      GOTO QUIT_SP
   END

   EXEC nspGetRight
      @c_Facility = @c_Facility
   ,  @c_Storerkey= @c_Storerkey
   ,  @c_Sku = ''
   ,  @c_Configkey= 'NIKEPackByCGD'
   ,  @b_Success  = @b_Success         OUTPUT
   ,  @c_Authority= @c_NIKEPackByCGD   OUTPUT
   ,  @n_Err      = @n_Err             OUTPUT
   ,  @c_ErrMsg   = @c_ErrMsg          OUTPUT

   IF  @b_Success <> 1
   BEGIN
      SET @n_continue = 3  
      SET @n_err = 60070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ERROR Executing nspGetRight - NIKEPackByCGD. (ispWAVPK05)' 
      GOTO QUIT_SP
   END    
   ----------------------------------------------------------------------------
   -- Clear Record Before START (START)
   ----------------------------------------------------------------------------
   SET @c_Loadkey = ''
   WHILE 1 = 1
   BEGIN
      SELECT TOP 1 @c_Loadkey = t.Loadkey
      FROM @tORDERS t
      WHERE t.Loadkey > @c_Loadkey
      ORDER BY t.Loadkey 
      
      IF @@ROWCOUNT = 0
      BEGIN 
         BREAK
      END

      SET @c_PickSlipNo = ''
      SELECT @c_PickSlipNo = P.PickHeaderKey
      FROM PICKHEADER P WITH (NOLOCK)
      WHERE P.ExternOrderkey = @c_Loadkey
      AND   P.LoadKey = @c_Loadkey

      IF @c_PickSlipNo <> ''
      BEGIN
         BEGIN TRAN
         SET @n_CartonNo = 0
         WHILE 1 = 1
         BEGIN
            SELECT TOP 1 @n_CartonNo = PD.CartonNo
            FROM PACKDETAIL PD WITH (NOLOCK)
            WHERE PD.PickSlipNo = @c_PickSlipNo
            AND   PD.CartonNo > @n_CartonNo
            ORDER BY PD.CartonNo
      
            IF @@ROWCOUNT = 0
            BEGIN 
               BREAK
            END

            DELETE PACKDETAIL
            WHERE PickSlipNo = @c_PickSlipNo
            AND   CartonNo = @n_CartonNo  
            
            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3  
               SET @n_err = 60080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PACKDETAIL fail. (ispWAVPK05)' 
               GOTO QUIT_SP
            END                
         END
         IF EXISTS ( SELECT 1
                     FROM PACKHEADER P WITH (NOLOCK)
                     WHERE P.PickSlipNo= @c_PickSlipNo
                     )
         BEGIN
            DELETE PACKHEADER
            WHERE PickSlipNo = @c_PickSlipNo
            
            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3  
               SET @n_err = 60090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PACKHEADER fail. (ispWAVPK05)' 
               GOTO QUIT_SP
            END 
         END
         WHILE @@TRANCOUNT > 0 
         BEGIN
            COMMIT TRAN
         END
      END
   END

   SET @CUR_PD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT CD.CartonKey
         ,CD.PickDetailKey
         ,CD.Sku
   FROM @tORDERS t
   JOIN CARTONLISTDETAIL CD WITH (NOLOCK) ON  t.OrderKey = CD.OrderKey              --(Wan01) -- do not link pickdetail if pickdetail unallocated
   --JOIN PICKDETAIL PD WITH (NOLOCK) ON T.Orderkey = PD.OrderKey                   --(Wan01)
   --JOIN CARTONLISTDETAIL CD WITH (NOLOCK) ON  PD.Pickdetailkey = CD.PickDetailKey --(Wan01)
   --WHERE PD.Qty > 0
   ORDER BY CD.CartonKey
         ,  CD.PickDetailKey

   OPEN @CUR_PD

   FETCH NEXT FROM @CUR_PD INTO  @c_CartonKey
                              ,  @c_PickDetailKey
                              ,  @c_Sku

   WHILE @@FETCH_STATUS = 0
   BEGIN
      BEGIN TRAN
      DELETE CARTONLISTDETAIL 
      WHERE CartonKey = @c_CartonKey 
      AND PickDetailKey = @c_PickDetailKey
      AND Sku = @c_Sku

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue = 3  
         SET @n_err = 60100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete CARTONLISTDETAIL Fail. (ispWAVPK05)' 
         GOTO QUIT_SP
      END 

      IF NOT EXISTS (SELECT 1
                     FROM CARTONLISTDETAIL WITH (NOLOCK)
                     WHERE CartonKey = @c_CartonKey
                     )
      BEGIN
         DELETE CARTONLIST 
         WHERE CartonKey = @c_CartonKey 

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3  
            SET @n_err = 60110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete CARTONLIST fail. (ispWAVPK05)' 
            GOTO QUIT_SP
         END 
      END
      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END
      FETCH NEXT FROM @CUR_PD INTO  @c_CartonKey
                                 ,  @c_PickDetailKey
                                 ,  @c_Sku
   END 
   CLOSE @CUR_PD
   DEALLOCATE @CUR_PD

   ----------------------------------------------------------------------------
   -- Clear Record Before START (END)
   ----------------------------------------------------------------------------

   CREATE TABLE #tPICKDETAIL   
      (  RowID             INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
      ,  DocumentKey       NVARCHAR(10)   NOT NULL
      ,  Loadkey           NVARCHAR(10)   NOT NULL
      ,  Pickdetailkey     NVARCHAR(10)   NOT NULL
      ,  OrderKey          NVARCHAR(10)   NOT NULL
      ,  OrderLineNumber   NVARCHAR(5)    NOT NULL
      ,  Storerkey         NVARCHAR(15)   NOT NULL
      ,  Sku               NVARCHAR(20)   NOT NULL
      ,  Qty               INT            NOT NULL
      ,  PickZone          NVARCHAR(10)   NOT NULL
      ,  [Site]            NVARCHAR(30)   NOT NULL
      ,  Division          NVARCHAR(30)   NOT NULL
      ,  Material          NVARCHAR(10)   NOT NULL
      ,  SkuCGD            NVARCHAR(18)   NOT NULL
      ,  SkuStdCube        FLOAT          NOT NULL
      ,  VASItemsCube      FLOAT          NOT NULL
      ,  SkuPackCube       FLOAT          NOT NULL
      ,  VAS               INT            NOT NULL
      ,  CartonType        NVARCHAR(10)   NOT NULL
      ,  CartonGroup       NVARCHAR(10)   NOT NULL
      ,  CartonCube        FLOAT          NOT NULL
      ,  PACKFACTOR        FLOAT          NOT NULL
      ,  RatioDivident     FLOAT          NOT NULL
      ,  RatioDivisor      FLOAT          NOT NULL
      ,  UOM               NVARCHAR(10)   NOT NULL
      --PRIMARY KEY CLUSTERED (Pickdetailkey)
      )

   CREATE TABLE #tCARTON   
      (
         CartonID          INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
      ,  CartonType        NVARCHAR(10)   NOT NULL
      ,  CartonGroup       NVARCHAR(10)   NOT NULL
      ,  CartonCube        FLOAT          NOT NULL
      ,  DocumentKey       NVARCHAR(10)   NOT NULL
      ,  Loadkey           NVARCHAR(10)   NOT NULL
      ,  PickZone          NVARCHAR(10)   NOT NULL
      ,  Division          NVARCHAR(30)   NOT NULL
      ,  Storerkey         NVARCHAR(15)   NOT NULL
      ,  Sku               NVARCHAR(20)   NOT NULL
      ,  Material          NVARCHAR(10)   NOT NULL DEFAULT ('')
      ,  SkuCGD            NVARCHAR(18)   NOT NULL DEFAULT ('')
      ,  VAS               INT            NOT NULL
      ,  [Status]          NVARCHAR(10)   NOT NULL
      --PRIMARY KEY CLUSTERED (LOT, LOC, ID)
      )

   CREATE TABLE #tCARTONDETAIL   
      ( 
         RowID             INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
      ,  CartonID          INT            NOT NULL  
      ,  Storerkey         NVARCHAR(15)   NOT NULL
      ,  Pickdetailkey     NVARCHAR(10)   NOT NULL
      ,  OrderKey          NVARCHAR(10)   NOT NULL
      ,  OrderLineNumber   NVARCHAR(5)    NOT NULL
      ,  Sku               NVARCHAR(20)   NOT NULL
      ,  Qty               INT            NOT NULL
      ,  PackCube          FLOAT          NOT NULL
      ,  [Site]            NVARCHAR(30)   NOT NULL
      ,  UOM               NVARCHAR(30)   NOT NULL 
      ,  SkuRatio          FLOAT          NOT NULL DEFAULT (0.00)
      ,  LastCartonBy      NVARCHAR(45)   NOT NULL                   --(Wan02)   
      --PRIMARY KEY CLUSTERED (LOT, LOC, ID)
      )

   SET @n_Cnt = 0

   SET @CUR_PD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT T.Loadkey
         ,PD.PickDetailKey
         ,PD.Orderkey
         ,PD.OrderLineNumber
         ,PD.Storerkey
         ,PD.Sku
         ,PickZone = RTRIM(L.PickZone)
         ,[Site] = CASE WHEN CL.UDF01 = 'N' THEN '' ELSE CL.Code END
         ,PD.Qty
   FROM @tORDERS T
   JOIN PICKDETAIL PD WITH (NOLOCK) ON T.Orderkey = PD.Orderkey
   JOIN LOC        L  WITH (NOLOCK) ON PD.Loc = L.Loc
   JOIN CODELKUP   CL WITH (NOLOCK) ON CL.ListName = 'ALLSorting'
                                    AND CL.Code2 = L.PickZone
                                    AND CL.Long = 'Y'
                                    AND CL.STORERKEY=PD.STORERKEY            --JSM-92837 
   ORDER BY PD.Storerkey, PD.Sku, RTRIM(L.PickZone)

   OPEN @CUR_PD

   FETCH NEXT FROM @CUR_PD INTO  @c_Loadkey
                              ,  @c_PickDetailKey
                              ,  @c_Orderkey
                              ,  @c_OrderLineNumber
                              ,  @c_Storerkey
                              ,  @c_Sku
                              ,  @c_PickZone
                              ,  @c_Site
                              ,  @n_Qty

   WHILE @@FETCH_STATUS = 0
   BEGIN 
      IF @c_Storerkey <> @c_Storerkey_Prev OR @c_Sku <> @c_Sku_Prev
      BEGIN
         --(Wan05) - START
         --IF @c_Storerkey <> @c_Storerkey_Prev
         --BEGIN
            SET @c_CartonGroup = ''
         --   SELECT @c_CartonGroup = ISNULL(RTRIM(S.CartonGroup),'')
         --   FROM STORER S WITH (NOLOCK)
         --   WHERE S.Storerkey = @c_Storerkey 
         --END
         --(Wan05) - END

         SET @c_Division = ''
         SET @c_Material = ''
         SET @c_SkuCGD   = ''
         SET @n_StdCube  = 0
         SET @n_PackQtyIndicator = 0                                       --(Wan05)   
         SET @n_PackFactor = 0                                             --(Wan05)         
         SELECT @c_Division = ISNULL(RTRIM(S.BUSR7),'')
            ,   @c_Material = ISNULL(RTRIM(S.ItemClass),'')
            ,   @c_SkuCGD   = CASE WHEN @c_NIKEPackByCGD = 1 THEN ISNULL(RTRIM(S.SUSR3),'') ELSE '' END
            ,   @c_CartonGroup = ISNULL(RTRIM(S.CartonGroup),'')            
            ,   @n_PackQtyIndicator = ISNULL(S.PackQtyIndicator,0)         --(Wan05)
            ,   @n_StdCube  = ISNULL(S.StdCube,0.00)   
            ,   @n_PackFactor = ISNULL(S.InnerPack,0.00)
         FROM SKU S WITH (NOLOCK)
         WHERE S.Storerkey = @c_Storerkey    
         AND   S.SKU = @c_Sku

         --(Wan05) - START
         SET @n_StdCube = @n_StdCube * @n_PackFactor

         --SET @n_CartonCube_X16 = 0
         --SET @n_CartonCube_X18 = 0
         --SELECT @n_CartonCube_X16 = ISNULL(MAX(CASE WHEN CZ.CartonType = 'X16' THEN CZ.[Cube] ELSE 0 END),0)
         --      ,@n_CartonCube_X18 = ISNULL(MAX(CASE WHEN CZ.CartonType = 'X18' THEN CZ.[Cube] ELSE 0 END),0)
         --FROM CARTONIZATION CZ WITH (NOLOCK)  
         --WHERE CZ.CartonizationGroup = @c_CartonGroup

         --SET @c_CartonType = 'X18' 
         --SET @n_CartonCube = @n_CartonCube_X18
         SET @c_CartonType = ''                                            --(Wan06)
         SET @n_CartonCube = 0.00                                          --(Wan06)
         SELECT TOP 1 
                @c_CartonType = CZ.CartonType
               ,@n_CartonCube = ISNULL(CZ.[Cube],0)
         FROM CARTONIZATION CZ WITH (NOLOCK)  
         WHERE CZ.CartonizationGroup = @c_CartonGroup
         ORDER BY CZ.[Cube] DESC

         SET @c_VasListName='NKSTAG'     
         IF @c_Division = 10  --Apparel      
         BEGIN
            SET @c_VasListName= 'NKSHANGER'
         END
         --(Wan05) - END   
      END

      SET @n_VASItemsCube = 0.00
      SET @n_VAS   = 0
      SELECT TOP 1 @n_VASItemsCube = CASE WHEN @c_Division = 10                                                                        --(Wan05) - 1
                                    --THEN ISNULL(SUM(CASE WHEN ISNUMERIC(CL.Notes) = 1 THEN CONVERT(FLOAT,CL.Notes) ELSE 0 END),0)
                                       THEN ISNULL(CASE WHEN ISNUMERIC(CL.Notes) = 1 THEN CONVERT(FLOAT,CL.Notes) ELSE 0 END,0)        --(Wan07) - 1
                                       ELSE 0
                                       END
            ,@n_VAS          = 1 --CASE WHEN COUNT(1) > 0 THEN 1 ELSE 0 END                                                            --(Wan05) - 1
      FROM ORDERS         OH  WITH (NOLOCK)
      JOIN ORDERDETAILREF ODR WITH (NOLOCK) ON  OH.Orderkey = ODR.Orderkey
      JOIN CODELKUP       CL  WITH (NOLOCK) ON  CL.ListName = @c_VasListName
                                            AND CL.Notes2   = ODR.Note1
                                            AND CL.Storerkey= @c_Storerkey
                                            AND (CL.code2   = OH.ConsigneeKey AND OH.ConsigneeKey <> '')                               --(Wan05) - 1
      WHERE OH.Orderkey = @c_Orderkey
      AND   ODR.OrderLineNumber = @c_OrderLineNumber
      
      SET @n_SkuPackCube = @n_StdCube + @n_VASItemsCube

      --(Wan05) - START
      --SET @n_RatioDivident = @n_Qty * 100
      --SET @n_RatioDivisor  = @n_PackFactor

      --IF @c_Division = 10  --Apparel  
      --BEGIN
         IF @n_CartonCube < @n_SkuPackCube
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60120
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_err) + ': Sku Pack Cube > Carton Cube. (ispWAVPK05)'
            GOTO QUIT_SP
         END
         --(Wan07) - START
         IF @n_CartonCube = 0 
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60122
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_err) + ': Carton Cube is 0. (ispWAVPK05)'
            GOTO QUIT_SP
         END
         --(Wan07) - END

         SET @n_PackFactor = CASE WHEN @n_SkuPackCube > 0.00 THEN @n_CartonCube / @n_SkuPackCube ELSE 0.00 END
         SET @n_PackFactor = ISNULL(FLOOR(CONVERT(DECIMAL(12,2), @n_PackFactor)),0.00)              --(Wan07)

         --(Wan07) - START
         SET @n_RatioDivident = @n_SkuPackCube * @n_Qty * 100
         SET @n_RatioDivisor  = @n_CartonCube

         IF @n_RatioDivident / @n_RatioDivident > 100 AND @n_PackFactor = 0 
         BEGIN
            SET @n_PackFactor =  ISNULL(FLOOR(CONVERT(DECIMAL(12,2), @n_SkuPackCube / @n_CartonCube)),0.00)
         END
         --(Wan07) - END

         IF @n_PackQtyIndicator > 1                                                                --(Wan05)
         BEGIN                                                                                     --(Wan05)
            SET @n_PackQtyLimit = ISNULL(FLOOR(CONVERT(DECIMAL(12,2), @n_PackFactor / @n_PackQtyIndicator * 1.00)),0)      --(Wan07)
                                    * @n_PackQtyIndicator                                          --(Wan05)
            IF  @n_PackQtyLimit < @n_PackFactor                                                    --(Wan05)
            BEGIN                                                                                  --(Wan05)
               SET @n_PackFactor = @n_PackQtyLimit                                                 --(Wan05)
            END                                                                                    --(Wan05)
         END                                                                                       --(Wan05)
         --SET @n_RatioDivident = @n_SkuPackCube * @n_Qty * 100                                    --(Wan07)
         --SET @n_RatioDivisor  = @n_CartonCube                                                    --(Wan07)    
      --END
      --(Wan05) - END

      INSERT INTO #tPICKDETAIL
            (  DocumentKey
            ,  Loadkey
            ,  PickDetailKey
            ,  OrderKey
            ,  OrderLineNumber
            ,  Storerkey
            ,  Sku
            ,  Qty 
            ,  PickZone
            ,  [Site]
            ,  Division
            ,  Material
            ,  SkuCGD
            ,  VAS
            ,  SkuStdCube
            ,  VASItemsCube
            ,  SkuPackCube
            ,  CartonGroup
            ,  CartonType
            ,  CartonCube
            ,  PackFactor
            ,  RatioDivident
            ,  RatioDivisor
            ,  UOM 
            )
      VALUES 
            (  @c_DocumentKey
            ,  @c_Loadkey
            ,  @c_PickDetailKey
            ,  @c_OrderKey
            ,  @c_OrderLineNumber
            ,  @c_Storerkey
            ,  @c_Sku
            ,  @n_Qty 
            ,  @c_PickZone
            ,  @c_Site 
            ,  @c_Division
            ,  @c_Material
            ,  @c_SkuCGD
            ,  @n_VAS
            ,  @n_StdCube
            ,  @n_VASItemsCube
            ,  @n_SkuPackCube
            ,  @c_CartonGroup
            ,  @c_CartonType
            ,  @n_CartonCube
            ,  @n_PackFactor
            ,  @n_RatioDivident
            ,  @n_RatioDivisor
            ,  ''
            )

      SET @n_Cnt = @n_Cnt + 1   
      SET @c_Storerkey_Prev = @c_Storerkey
      SET @c_Sku_Prev = @c_Sku
                        
      FETCH NEXT FROM @CUR_PD INTO  @c_Loadkey
                                 ,  @c_PickDetailKey
                                 ,  @c_Orderkey
                                 ,  @c_OrderLineNumber
                                 ,  @c_Storerkey
                                 ,  @c_Sku
                                 ,  @c_PickZone
                                 ,  @c_Site
                                 ,  @n_Qty
   END
   CLOSE @CUR_PD
   DEALLOCATE @CUR_PD

   IF @n_Cnt = 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 60130
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_err) + ': No Pickdetail record for Precartonization found. (ispWAVPK05)'   -- (Wan06)
      GOTO AUTO_SCANIN                                                                                                           -- (Wan06)
   END

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   IF @b_debug = 1
   BEGIN
      SELECT   P.DocumentKey
            ,  P.Loadkey
            ,  P.PickZone
            ,  P.Division
            ,  P.Storerkey
            ,  P.Sku
            ,  P.VAS
            ,  P.CartonGroup
            ,  P.CartonType
            ,  P.CartonCube 
            ,  SUMqty = SUM( P.Qty * 1.00)
            ,  SkuQtyPerCTN = ISNULL(P.PackFactor, 0.00)                                                     
            ,  NoOfCTN = FLOOR(CONVERT(DECIMAL(12,2),ISNULL(SUM( P.Qty * 1.00) / P.PackFactor, 0.00)))       
            ,  P.PackFactor                                                                                    
      FROM #tPICKDETAIL P
      WHERE P.UOM = ''
      GROUP BY P.DocumentKey
            ,  P.Loadkey
            ,  P.PickZone
            ,  P.Division
            ,  P.Storerkey
            ,  P.Sku
            ,  P.VAS
            ,  P.CartonGroup
            ,  P.CartonType
            ,  P.CartonCube
            ,  P.PackFactor
   END

   ----------------------------------------------------------------------
   -- Build Carton for Same Loadkey, PickZone, Division, Sku, VAS (START)
   ----------------------------------------------------------------------
   SET @CUR_SKUCTN = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT   P.DocumentKey
         ,  P.Loadkey
         ,  P.PickZone
         ,  P.Division
         ,  P.Storerkey
         ,  P.Sku
         ,  P.VAS
         ,  P.CartonGroup
         ,  P.CartonType
         ,  P.CartonCube
         ,  SkuQtyPerCTN = ISNULL(P.PackFactor, 0.00)                                              --(Wan07)
         ,  NoOfCTN = FLOOR(CONVERT(DECIMAL(12,2),ISNULL(SUM( P.Qty * 1.00) / P.PackFactor, 0.00)))--(Wan07)
   FROM #tPICKDETAIL P
   WHERE P.UOM = ''
   AND P.PackFactor > 0
   GROUP BY P.DocumentKey
         ,  P.Loadkey
         ,  P.PickZone
         ,  P.Division
         ,  P.Storerkey
         ,  P.Sku
         ,  P.VAS
         ,  P.CartonGroup
         ,  P.CartonType
         ,  P.CartonCube
         ,  P.PackFactor
   HAVING FLOOR(CONVERT(DECIMAL(12,2),ISNULL(SUM( P.Qty * 1.00) / P.PackFactor, 0.00))) > 0.00     --(Wan07)

   OPEN @CUR_SKUCTN

   FETCH NEXT FROM @CUR_SKUCTN INTO @c_DocumentKey
                                 ,  @c_Loadkey
                                 ,  @c_PickZone
                                 ,  @c_Division
                                 ,  @c_Storerkey
                                 ,  @c_Sku
                                 ,  @n_VAS
                                 ,  @c_CartonGroup
                                 ,  @c_CartonType
                                 ,  @n_CartonCube
                                 ,  @n_SkuQtyPerCTN
                                 ,  @n_NoOfCTN
   WHILE @@FETCH_STATUS = 0
   BEGIN 
      SET @n_RemainingPerCTN = @n_SkuQtyPerCTN
 
      IF @n_NoOfCTN = 0 OR @n_RemainingPerCTN = 0 
      BEGIN 
         GOTO NEXT_SKUCTN
      END  

      SET @CUR_PD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT   P.RowID
            ,  P.PickDetailKey
            ,  P.Qty
      FROM #tPICKDETAIL P
      WHERE P.UOM = ''
      AND P.Loadkey  = @c_Loadkey               --(Wan01)
      AND P.PickZone = @c_PickZone
      AND P.Division = @c_Division
      AND P.Storerkey= @c_Storerkey
      AND P.Sku      = @c_Sku
      AND P.VAS      = @n_VAS
      AND P.CartonGroup= @c_CartonGroup
      AND P.CartonType = @c_CartonType
      ORDER BY P.Qty DESC

      OPEN @CUR_PD

      FETCH NEXT FROM @CUR_PD INTO  @n_RowID
                                 ,  @c_PickDetailKey
                                 ,  @n_Qty

      WHILE @@FETCH_STATUS = 0 AND @n_NoOfCTN > 0 AND @n_RemainingPerCTN > 0 
      BEGIN 
         IF @b_Debug = 1
         BEGIN
            IF @c_Sku = '425015101XL'
               SELECT  @n_NoOfCTN '@n_NoOfCTN', @n_RemainingPerCTN '@n_RemainingPerCTN' , @n_SkuQtyPerCTN '@n_SkuQtyPerCTN'          
         END

         WHILE @n_Qty > 0 AND @n_NoOfCTN > 0
         BEGIN 
            IF @n_RemainingPerCTN = @n_SkuQtyPerCTN
            BEGIN
               INSERT INTO #tCARTON 
                  (  CartonGroup
                  ,  CartonType
                  ,  CartonCube
                  ,  DocumentKey
                  ,  Loadkey
                  ,  PickZone
                  ,  Division
                  ,  Storerkey
                  ,  Sku
                  ,  VAS 
                  ,  [Status]
                  )
               VALUES 
                  (  @c_CartonGroup
                  ,  @c_CartonType
                  ,  @n_CartonCube
                  ,  @c_DocumentKey
                  ,  @c_Loadkey
                  ,  @c_PickZone
                  ,  @c_Division
                  ,  @c_Storerkey
                  ,  @c_Sku
                  ,  @n_VAS 
                  , '9'       -- CLOSE
                  )

               SET @n_CartonID = @@IDENTITY
            END

            SET @n_InsertPackQty   = 0             --(Wan04)
            SET @n_SplitQty        = 0             --(Wan04)
            SET @n_RatioQty        = 0             --(Wan04)
            SET @n_SplitPickDetail = 0
            IF @n_RemainingPerCTN >= @n_Qty 
            BEGIN
               SET @n_InsertPackQty = @n_Qty
               SET @n_RatioQty = @n_InsertPackQty  --(Wan04)
            END
            ELSE 
            BEGIN
               SET @n_InsertPackQty = @n_RemainingPerCTN
               SET @n_SplitPickDetail = 1
               SET @n_SplitQty = @n_Qty - @n_RemainingPerCTN
               SET @n_RatioQty = @n_SplitQty       --(Wan04)
            END

            IF @b_Debug = 1
            BEGIN
               IF @c_Sku = '425015101XL'
                  SELECT   @n_SplitQty '@n_SplitQty' , @n_InsertPackQty '@n_InsertPackQty'  , @n_RemainingPerCTN '@n_RemainingPerCTN' , @n_SkuQtyPerCTN '@n_SkuQtyPerCTN'         
            END

            IF @n_InsertPackQty > 0 
            BEGIN
               INSERT INTO #tCARTONDETAIL
                  (  CartonID
                  ,  PickDetailKey
                  ,  Orderkey
                  ,  OrderLineNumber 
                  ,  Storerkey
                  ,  Sku
                  ,  Qty
                  ,  PackCube
                  , [Site] 
                  ,  UOM
                  ,  SkuRatio
                  ,  LastCartonBy                                                      --(Wan02)
                  )
               SELECT
                     @n_CartonID
                  ,  PickDetailKey
                  ,  Orderkey
                  ,  OrderLineNumber 
                  ,  Storerkey
                  ,  Sku
                  ,  @n_InsertPackQty 
                  ,  SkuPackCube * @n_InsertPackQty
                  , [Site]
                  ,  '2'
                  ,  0.00
                  , ''                                                                 --(Wan05) 
               FROM #tPICKDETAIL 
               WHERE RowID = @n_RowID
            END

            UPDATE #tPICKDETAIL
               SET Qty = CASE WHEN @n_SplitPickDetail = 1 THEN @n_InsertPackQty ELSE Qty END
                  ,UOM = '2'
                  ,RatioDivident = SkuPackCube * @n_InsertPackQty * 100                --(Wan07)
            WHERE RowID = @n_RowId

            IF @n_SplitPickDetail = 1
            BEGIN
               BEGIN TRAN 
               SET @c_NewPickDetailkey = ''  
               EXEC dbo.nspg_GetKey   
                     @KeyName     = 'PICKDETAILKEY'
                  ,  @fieldlength =  9
                  ,  @keystring   = @c_NewPickDetailkey  OUTPUT
                  ,  @b_Success   = @b_Success           OUTPUT
                  ,  @n_Err       = @n_Err               OUTPUT
                  ,  @c_Errmsg    = @c_Errmsg            OUTPUT      
               
               IF @b_success <> 1
               BEGIN
                  SET @n_continue = 3  
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                  SET @n_err = 60140   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Executing nspg_GetKey - PICKDETAILKEY. (ispWAVPK05)' 
                               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
                  GOTO QUIT_SP
               END

               UPDATE PICKDETAIL
                  SET Qty = @n_InsertPackQty
                     ,Trafficcop = NULL
                     ,EditWho = SUSER_NAME()
                     ,EditDate= GETDATE()
               WHERE PickDetailKey = @c_PickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @n_continue = 3  
                  SET @n_err = 60150   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE PICKDETAIL fail. (ispWAVPK05)' 
                  GOTO QUIT_SP
               END

               INSERT INTO PICKDETAIL
                     (  PickDetailKey                       
                     ,  CaseID                              
                     ,  PickHeaderKey                       
                     ,  OrderKey                            
                     ,  OrderLineNumber                     
                     ,  Lot                                 
                     ,  Storerkey                           
                     ,  Sku                                 
                     ,  AltSku                              
                     ,  UOM                                 
                     ,  UOMQty                              
                     ,  Qty                                 
                     ,  QtyMoved                            
                     ,  [Status]                              
                     ,  DropID                              
                     ,  Loc                                 
                     ,  ID                                  
                     ,  PackKey                             
                     ,  UpdateSource                        
                     ,  CartonGroup                         
                     ,  CartonType                          
                     ,  ToLoc                               
                     ,  DoReplenish                         
                     ,  ReplenishZone                       
                     ,  DoCartonize                         
                     ,  PickMethod                          
                     ,  WaveKey                             
                     ,  EffectiveDate                       
                     ,  AddDate                             
                     ,  AddWho                              
                     ,  EditDate                            
                     ,  EditWho                             
                     ,  TrafficCop                          
                     ,  ArchiveCop                          
                     ,  OptimizeCop                         
                     ,  ShipFlag                            
                     ,  PickSlipNo                          
                     ,  TaskDetailKey                       
                     ,  TaskManagerReasonKey                
                     ,  Notes                               
                     ,  MoveRefKey                          
                     ,  Channel_ID
                     )  
               SELECT  
                        @c_NewPickDetailKey                       
                     ,  CaseID                              
                     ,  PickHeaderKey                       
                     ,  OrderKey                            
                     ,  OrderLineNumber                     
                     ,  Lot                                 
                     ,  Storerkey                           
                     ,  Sku                                 
                     ,  AltSku                              
                     ,  UOM                                 
                     ,  UOMQty                              
                     ,  @n_SplitQty                                 
                     ,  QtyMoved                            
                     ,  [Status]                              
                     ,  DropID                              
                     ,  Loc                                 
                     ,  ID                                  
                     ,  PackKey                             
                     ,  UpdateSource                        
                     ,  CartonGroup                         
                     ,  CartonType                          
                     ,  ToLoc                               
                     ,  DoReplenish                         
                     ,  ReplenishZone                       
                     ,  DoCartonize                         
                     ,  PickMethod                          
                     ,  WaveKey                             
                     ,  EffectiveDate                       
                     ,  GETDATE()                             
                     ,  SUSER_NAME()                             
                     ,  EditDate                            
                     ,  EditWho                             
                     ,  TrafficCop                          
                     ,  ArchiveCop                          
                     ,  'Y'                         
                     ,  ShipFlag                            
                     ,  PickSlipNo                          
                     ,  TaskDetailKey                       
                     ,  TaskManagerReasonKey                
                     ,  Pickdetailkey                               
                     ,  MoveRefKey                          
                     ,  Channel_ID  
               FROM PICKDETAIL WITH (NOLOCK)
               WHERE PickDetailKey = @c_PickDetailKey                                         

               IF @@ERROR <> 0
               BEGIN
                  SET @n_continue = 3  
                  SET @n_err = 60160   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': INSERT PICKDETAIL fail. (ispWAVPK05)' 
                  GOTO QUIT_SP
               END

               WHILE @@TRANCOUNT > 0 
               BEGIN
                  COMMIT TRAN
               END
  
               INSERT INTO #tPICKDETAIL
                     (  DocumentKey
                     ,  Loadkey
                     ,  PickDetailKey
                     ,  OrderKey
                     ,  OrderLineNumber
                     ,  Storerkey
                     ,  Sku
                     ,  Qty 
                     ,  [Site]
                     ,  PickZone
                     ,  Division
                     ,  Material
                     ,  SkuCGD
                     ,  VAS
                     ,  SkuStdCube
                     ,  VASItemsCube
                     ,  SkuPackCube
                     ,  CartonGroup
                     ,  CartonType
                     ,  CartonCube
                     ,  PackFactor
                     ,  RatioDivident
                     ,  RatioDivisor
                     ,  UOM
                     )
               SELECT   DocumentKey
                     ,  Loadkey
                     ,  @c_NewPickDetailKey
                     ,  OrderKey
                     ,  OrderLineNumber
                     ,  Storerkey
                     ,  Sku
                     ,  @n_SplitQty 
                     ,  [Site]
                     ,  PickZone
                     ,  Division
                     ,  Material
                     ,  SkuCGD
                     ,  VAS
                     ,  SkuStdCube
                     ,  VASItemsCube
                     ,  SkuPackCube
                     ,  CartonGroup
                     ,  CartonType
                     ,  CartonCube
                     ,  PackFactor
                     ,  SkuPackCube * @n_SplitQty * 100                                --(Wan05)                                               
                     ,  RatioDivisor
                     ,  ''
               FROM #tPICKDETAIL 
               WHERE RowID = @n_RowID

               SET @n_NewRowID = @@IDENTITY
            END

            SET @n_RemainingPerCTN = @n_RemainingPerCTN - @n_InsertPackQty
            SET @n_Qty = @n_Qty - @n_InsertPackQty

            IF @b_Debug = 1
            BEGIN
               IF @c_Sku = '425015101XL'
                  SELECT   @n_RemainingPerCTN '@n_RemainingPerCTN' , @n_Qty '@n_Qty'  ,  @n_SplitPickDetail ' @n_SplitPickDetail'        
            END

            IF @n_Qty > 0 AND @n_SplitPickDetail = 1
            BEGIN
               SET @c_PickDetailKey = @c_NewPickDetailKey
               SET @n_RowID = @n_NewRowID
            END

            IF @n_RemainingPerCTN = 0
            BEGIN
               SET @n_RemainingPerCTN = @n_SkuQtyPerCTN
               SET @n_NoOfCTN = @n_NoOfCTN - 1
            END
         END 

         FETCH NEXT FROM @CUR_PD INTO  @n_RowID
                                    ,  @c_PickDetailKey
                                    ,  @n_Qty
      END
      CLOSE @CUR_PD
      DEALLOCATE @CUR_PD

      NEXT_SKUCTN:
      FETCH NEXT FROM @CUR_SKUCTN INTO @c_DocumentKey
                                    ,  @c_Loadkey
                                    ,  @c_PickZone
                                    ,  @c_Division
                                    ,  @c_Storerkey
                                    ,  @c_Sku
                                    ,  @n_VAS
                                    ,  @c_CartonGroup
                                    ,  @c_CartonType
                                    ,  @n_CartonCube
                                    ,  @n_SkuQtyPerCTN
                                    ,  @n_NoOfCTN
   END
   CLOSE @CUR_SKUCTN
   DEALLOCATE @CUR_SKUCTN
   ----------------------------------------------------------------------
   -- Build Carton for Same Loadkey, PickZone, Division, Sku, VAS (END)
   ----------------------------------------------------------------------

   -------------------------------------------------------------------------------------
   -- Build Carton for Same Loadkey PickZone, Division, Material or and CGD, VAS (START)
   -------------------------------------------------------------------------------------
   IF @b_debug = 1
   BEGIN
      SELECT   P.DocumentKey
            ,  P.Loadkey
            ,  P.PickZone
            ,  P.Division
            ,  P.Storerkey
            ,  P.Material
            ,  P.SkuCGD
            ,  P.VAS
            ,  P.CartonGroup
            ,  P.CartonType
            ,  P.CartonCube
      FROM #tPICKDETAIL P
      WHERE P.UOM = ''
      GROUP BY P.DocumentKey
            ,  P.Loadkey
            ,  P.PickZone
            ,  P.Division
            ,  P.Storerkey
            ,  P.Material
            ,  P.SkuCGD
            ,  P.VAS
            ,  P.CartonGroup
            ,  P.CartonType
            ,  P.CartonCube
      ORDER BY P.DocumentKey
            ,  P.Loadkey
            ,  P.PickZone
            ,  P.Division
            ,  P.Storerkey
            ,  P.VAS
            ,  P.Material
            ,  P.SkuCGD
   END

   SET @CUR_MIXCTN = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT   P.DocumentKey
         ,  P.Loadkey
         ,  P.PickZone
         ,  P.Division
         ,  P.Storerkey
         ,  P.Material
         ,  P.SkuCGD
         ,  P.VAS
         ,  P.CartonGroup
         ,  P.CartonType
         ,  P.CartonCube
   FROM #tPICKDETAIL P
   WHERE P.UOM = ''
   GROUP BY P.DocumentKey
         ,  P.Loadkey
         ,  P.PickZone
         ,  P.Division
         ,  P.Storerkey
         ,  P.Material
         ,  P.SkuCGD
         ,  P.VAS
         ,  P.CartonGroup
         ,  P.CartonType
         ,  P.CartonCube
   --(Wan03) - START
   ORDER BY P.DocumentKey     
         ,  P.Loadkey
         ,  P.PickZone
         ,  P.Division
         ,  P.Storerkey
         ,  P.VAS
         ,  P.Material
         ,  P.SkuCGD
   --(Wan03) - END
   OPEN @CUR_MIXCTN

   FETCH NEXT FROM @CUR_MIXCTN INTO @c_DocumentKey
                                 ,  @c_Loadkey
                                 ,  @c_PickZone
                                 ,  @c_Division
                                 ,  @c_Storerkey
                                 ,  @c_Material
                                 ,  @c_SkuCGD
                                 ,  @n_VAS
                                 ,  @c_CartonGroup
                                 ,  @c_CartonType
                                 ,  @n_CartonCube

   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT P.Loadkey, P.Sku, P.SkuPackCube, P.Qty, P.CartonCube  , P.RatioDivident , P.RatioDivisor      
         FROM #tPICKDETAIL P
         WHERE P.UOM = ''
         AND P.Loadkey  = @c_Loadkey               --(Wan01)

         SELECT   @c_Loadkey 'Loadkey'
               ,  P.Storerkey
               ,  P.Sku
               ,  Qty = SUM(P.Qty)
               ,  SkuRatio = ISNULL(SUM(CASE WHEN P.RatioDivisor = 0.00 
                                             THEN 0 
                                             ELSE P.RatioDivident / P.RatioDivisor * 1.00
                                             END), 0.00 )
               , @c_PickZone '@c_PickZone'
               ,@c_Division '@c_Division'
               ,@c_Storerkey '@c_Storerkey'
               ,@c_Material '@c_Material'
               ,@c_SkuCGD '@c_SkuCGD'
               ,@n_VAS '@n_VAS'
               ,@c_CartonGroup '@c_CartonGroup'
               ,@c_CartonType '@@c_CartonType'
         FROM #tPICKDETAIL P
         WHERE P.UOM = ''
         AND P.Loadkey  = @c_Loadkey               --(Wan01)
         AND P.PickZone = @c_PickZone
         AND P.Division = @c_Division
         AND P.Storerkey= @c_Storerkey
         AND P.Material = @c_Material
         AND P.SkuCGD   = @c_SkuCGD
         AND P.VAS      = @n_VAS
         AND P.CartonGroup= @c_CartonGroup
         AND P.CartonType = @c_CartonType
         GROUP BY P.Storerkey
               ,  P.Sku
         ORDER BY SkuRatio
      END

      SET @CUR_PD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT   P.Storerkey
            ,  P.Sku
            ,  Qty = SUM(P.Qty)
            ,  SkuRatio = ISNULL(SUM(CASE WHEN P.RatioDivisor = 0.00 
                                  THEN 0 
                                  ELSE P.RatioDivident / P.RatioDivisor * 1.00
                                  END), 0.00 )
      FROM #tPICKDETAIL P
      WHERE P.UOM = ''
      AND P.Loadkey  = @c_Loadkey               --(Wan01)
      AND P.PickZone = @c_PickZone
      AND P.Division = @c_Division
      AND P.Storerkey= @c_Storerkey
      AND P.Material = @c_Material
      AND P.SkuCGD   = @c_SkuCGD
      AND P.VAS      = @n_VAS
      AND P.CartonGroup= @c_CartonGroup
      AND P.CartonType = @c_CartonType
      GROUP BY P.Storerkey
            ,  P.Sku
      ORDER BY SkuRatio

      OPEN @CUR_PD

      FETCH NEXT FROM @CUR_PD INTO  @c_Storerkey
                                 ,  @c_Sku
                                 ,  @n_Qty
                                 ,  @n_SkuRatio

      WHILE @@FETCH_STATUS = 0 --AND @n_RemainingPerCTN > 0 
      BEGIN 
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Sku '@c_Sku', @n_SkuRatio '@n_SkuRatio'

            SELECT C.CartonID,SUM(CD.SkuRatio)
            FROM #tCARTON         C
            JOIN #tCARTONDETAIL   CD ON C.CartonID = CD.CartonID
            WHERE C.DocumentKey = @c_DocumentKey
            AND   C.Loadkey     = @c_Loadkey
            AND   C.PickZone    = @c_PickZone
            AND   C.Division    = @c_Division
            AND   C.Storerkey   = @c_Storerkey
            AND   C.Material    = @c_Material
            AND   C.SkuCGD      = @c_SkuCGD
            AND   C.VAS         = @n_VAS
            AND   C.CartonGroup = @c_CartonGroup
            AND   C.CartonType  = @c_CartonType
            AND   C.[Status]    = '0'
            GROUP BY C.CartonID
            HAVING 100.00 - SUM(CD.SkuRatio) >= @n_SkuRatio
            ORDER BY SUM(CD.SkuRatio) DESC
         END

         SET @n_CartonID = 0
         SET @n_TotalRatio = 0     --AL01   
         SELECT TOP 1 @n_CartonID = C.CartonID
                  ,   @n_TotalRatio = ISNULL(SUM(CD.SkuRatio),0)
         FROM #tCARTON         C
         JOIN #tCARTONDETAIL   CD ON C.CartonID = CD.CartonID
         WHERE C.DocumentKey = @c_DocumentKey
         AND   C.Loadkey     = @c_Loadkey
         AND   C.PickZone    = @c_PickZone
         AND   C.Division    = @c_Division
         AND   C.Storerkey   = @c_Storerkey
         AND   C.Material    = @c_Material
         AND   C.SkuCGD      = @c_SkuCGD
         AND   C.VAS         = @n_VAS
         AND   C.CartonGroup = @c_CartonGroup
         AND   C.CartonType  = @c_CartonType
         AND   C.[Status]    = '0'
         GROUP BY C.CartonID
         HAVING 100.00 - ISNULL(SUM(SkuRatio),0) >= @n_SkuRatio    
         ORDER BY ISNULL(SUM(CD.SkuRatio),0)  DESC    

         IF @n_CartonID = 0
         BEGIN
            INSERT INTO #tCARTON 
               (  CartonGroup
               ,  CartonType
               ,  CartonCube
               ,  DocumentKey
               ,  Loadkey
               ,  PickZone
               ,  Division
               ,  Storerkey
               ,  Sku
               ,  Material
               ,  SkuCGD 
               ,  VAS 
               ,  [Status]
               )
            VALUES 
               (  @c_CartonGroup
               ,  @c_CartonType
               ,  @n_CartonCube
               ,  @c_DocumentKey
               ,  @c_Loadkey
               ,  @c_PickZone
               ,  @c_Division
               ,  @c_Storerkey
               ,  ''
               ,  @c_Material
               ,  @c_SkuCGD 
               ,  @n_VAS 
               , '0'       -- CLOSE
               )
            SET @n_CartonID = @@IDENTITY
         END

         SET @n_RowID = 0
         WHILE 1 = 1
         BEGIN 
            SET @n_InsertPackQty = 0
            SELECT TOP 1 @n_RowID = RowID
                        ,@n_InsertPackQty = Qty
            FROM #tPICKDETAIL 
            WHERE DocumentKey = @c_DocumentKey
            AND   Loadkey     = @c_Loadkey
            AND   PickZone    = @c_PickZone
            AND   Division    = @c_Division
            AND   Storerkey   = @c_Storerkey
            AND   Sku         = @c_Sku
            AND   Material    = @c_Material
            AND   VAS         = @n_VAS
            AND   CartonGroup = @c_CartonGroup
            AND   CartonType  = @c_CartonType
            AND   UOM         = ''
            AND   RowID > @n_RowID 
            ORDER BY RowID
            
            IF @@ROWCOUNT = 0
            BEGIN
               BREAK
            END   

            INSERT INTO #tCARTONDETAIL
               (  CartonID
               ,  PickDetailKey
               ,  Orderkey
               ,  OrderLineNumber 
               ,  Storerkey
               ,  Sku
               ,  Qty 
               ,  PackCube
               ,  SkuRatio 
               ,  [Site]
               ,  UOM
               ,  LastCartonBy                                                      --(Wan02)
               )
            SELECT
                  @n_CartonID
               ,  PickDetailKey
               ,  Orderkey
               ,  OrderLineNumber 
               ,  Storerkey
               ,  Sku
               ,  @n_InsertPackQty 
               ,  SkuPackCube * @n_InsertPackQty
               ,  CASE WHEN RatioDivisor = 0 THEN 0 ELSE RatioDivident / RatioDivisor * 1.00  END --@n_SkuRatio
               ,  [Site]
               ,  '7'
               ,  CASE WHEN [Site] <> '' 
                       THEN @c_Loadkey + '_' + [Site] + '_' + PickZone + '_' + @c_Material + '_' + CONVERT(CHAR(1), @n_VAS)
                       ELSE '' 
                       END   --(Wan02) 
            FROM #tPICKDETAIL 
            WHERE RowID = @n_RowID

            UPDATE #tPICKDETAIL
               SET UOM = '7'
            WHERE RowID = @n_RowId
         END

         IF @n_SkuRatio = 100 -  @n_TotalRatio
         BEGIN
            UPDATE #tCARTON 
               SET Status = '9'
            WHERE CartonID = @n_CartonID
         END

         FETCH NEXT FROM @CUR_PD INTO  @c_Storerkey
                                    ,  @c_Sku
                                    ,  @n_Qty
                                    ,  @n_SkuRatio
      END
      CLOSE @CUR_PD
      DEALLOCATE @CUR_PD
  
      FETCH NEXT FROM @CUR_MIXCTN INTO @c_DocumentKey
                                    ,  @c_Loadkey
                                    ,  @c_PickZone
                                    ,  @c_Division
                                    ,  @c_Storerkey
                                    ,  @c_Material
                                    ,  @c_SkuCGD 
                                    ,  @n_VAS
                                    ,  @c_CartonGroup
                                    ,  @c_CartonType
                                    ,  @n_CartonCube
   END
   CLOSE @CUR_MIXCTN
   DEALLOCATE @CUR_MIXCTN

   -----------------------------------------------------------------------------
   -- Build Carton for Same PickZone, Division, Material or and CGD, VAS (END)
   -----------------------------------------------------------------------------
   
   -----------------------------------------------------------------------------
   -- Combine Last Cartons for different Material (START)
   -----------------------------------------------------------------------------
   INSERT INTO @TLASTCTN
      (
         Loadkey
      ,  PickZone
      ,  Division
      ,  Material
      ,  SkuCGD
      ,  VAS
      --,  [Site]  
      ,  CartonGroup          
      ,  CartonID   
      ,  TotalPackCube
      ,  TotalRatio   
      )
   SELECT 
         LC.Loadkey
      ,  LC.PickZone
      ,  LC.Division
      ,  LC.Material
      ,  LC.SkuCGD
      ,  LC.VAS
      --,  [Site] 
      ,  LC.CartonGroup
      ,  LC.CartonID
      ,  TotalPackCube = ISNULL(SUM(CD.PackCube),0.00)
      ,  TotalRatio    = ISNULL(SUM(CD.SkuRatio),0.00) 
   FROM
      (   
      SELECT 
            C.Loadkey
         ,  C.PickZone
         ,  C.Division 
         ,  C.Material
         ,  C.SKUCGD
         ,  C.VAS
         --,  CD.[Site]
         ,  C.CartonGroup
         ,  CartonID    = ISNULL(MAX(C.CartonID),0)
      FROM #tCARTON C
      GROUP BY C.Loadkey  
            ,  C.PickZone 
            ,  C.Division 
            ,  C.Material 
            ,  C.SKUCGD   
            ,  C.VAS      
            --,  CD.[Site] 
            ,  C.CartonGroup 
      ) LC
   JOIN #tCARTONDETAIL CD ON LC.CartonID = CD.CartonID
   WHERE CD.UOM = '7'
   GROUP BY
         LC.Loadkey
      ,  LC.PickZone
      ,  LC.Division
      ,  LC.Material
      ,  LC.SkuCGD
      ,  LC.VAS
      ,  LC.CartonGroup
      ,  LC.CartonID
   ORDER BY 
         LC.Loadkey
      ,  LC.PickZone
      ,  LC.Division
      ,  LC.Material
      ,  LC.SkuCGD
      ,  LC.VAS
      ,  TotalRatio DESC   
   
   COMBINE_CTN:
   SET @n_RowID = 0
   SET @c_Loadkey   = ''
   SET @c_PickZone  = ''
   SET @c_Division  = ''
   SET @c_Material  = ''
   SET @c_SkuCGD    = ''
   SET @n_VAS       = ''
   --SET @c_Site      = ''
   SET @c_CartonGroup = ''
   SET @n_Add2CartonID= ''
   SET @n_TotalRatio= 0.00
   SET @n_TotalPackCube = 0.00
   SELECT TOP 1 
          @c_Loadkey   = LC.Loadkey
      ,   @c_PickZone  = LC.PickZone
      ,   @c_Division  = LC.Division 
      ,   @c_Material  = LC.Material
      ,   @c_SkuCGD    = LC.SKUCGD
      ,   @n_VAS       = LC.VAS
      --,   @c_Site      = LC.[Site]
      ,   @n_RowID     = LC.RowID 
      ,   @c_CartonGroup = LC.CartonGroup
      ,   @n_Add2CartonID= LC.CartonID
      ,   @n_TotalRatio= LC.TotalRatio
      ,   @n_TotalPackCube = LC.TotalPackCube
   FROM @TLASTCTN LC
   WHERE LC.Status = '0'
   ORDER BY LC.RowID
   
   SET @n_Add2RowID  = @n_RowID
   IF @n_RowID > 0 
   BEGIN
      WHILE 1 = 1
      BEGIN
         SET @n_CartonID = 0
         SET @n_SkuRatio = 0.00
         SET @n_PackCube = 0.00
         SELECT TOP 1 
                @n_RowID      = LC.RowID
            ,   @n_CartonID   = LC.CartonID
            ,   @n_SkuRatio   = LC.TotalRatio
            ,   @n_PackCube   = LC.TotalPackCube
         FROM @TLASTCTN LC
         WHERE LC.RowID > @n_RowID
         AND LC.Loadkey = @c_Loadkey 
         AND LC.PickZone= @c_PickZone
         AND LC.Division= @c_Division
         AND LC.SkuCGD  = @c_SKUCGD  
         AND LC.VAS     = @n_VAS     
         --AND LC.[Site]  = @c_Site  
         AND LC.Status = '0'
         ORDER BY LC.RowID                                            

         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END
         
         IF @n_TotalRatio + @n_SkuRatio <= 100
         BEGIN
            UPDATE #TCARTONDETAIL
            SET CartonID = @n_Add2CartonID
            WHERE CartonID = @n_CartonID
            
            UPDATE #TCARTON
            SET Status = 'X'
            WHERE CartonID = @n_CartonID
            
            UPDATE @TLASTCTN
            SET Status = 'X'
            WHERE RowID = @n_RowID 
            
            SET @n_TotalRatio   = @n_TotalRatio + @n_SkuRatio
            SET @n_TotalPackCube= @n_TotalPackCube + @n_PackCube
         END   
      END

      UPDATE @TLASTCTN
      SET Status = '9'
         ,TotalRatio = @n_TotalRatio
         ,TotalPackCube = @n_TotalPackCube
      WHERE RowID = @n_Add2RowID 

      SELECT TOP 1 
             @c_CartonType = CZ.CartonType
            ,@n_CartonCube = ISNULL(CZ.[Cube],0.00)
      FROM CARTONIZATION CZ WITH (NOLOCK)  
      WHERE CZ.CartonizationGroup = @c_CartonGroup
      AND CZ.[Cube] >= @n_TotalPackCube
      ORDER BY CZ.[Cube] 
      
      IF EXISTS ( SELECT 1
                  FROM #TCARTON C
                  WHERE CartonID = @n_Add2CartonID      
                  AND CartonType <> @c_CartonType
                )
      BEGIN
         UPDATE #TCARTON
         SET CartonType = @c_CartonType
            ,CartonCube = @n_TotalPackCube
         WHERE CartonID = @n_Add2CartonID        
      END               

      GOTO COMBINE_CTN
   END       
 
   -----------------------------------------------------------------------------
   -- Combine Last Cartons for different Material (END)
   -----------------------------------------------------------------------------
   ----------------------------------------------------------------------------------
   -- CREATE CARTON, CARTONLIST, PICKHEADER, PACKHEADER, PACKDETAIL, PACKINFO (START)
   -- AUTO SCAN IN
   ----------------------------------------------------------------------------------
AUTO_SCANIN:
   IF @b_debug = 1
   BEGIN
      SELECT 'CARTON',  *
      FROM #tCARTON C

      SELECT '#tCARTONDETAIL', *
      FROM #tCARTONDETAIL C
   END

   SET @c_Loadkey = ''
   WHILE 1= 1
   BEGIN
      --(Wan06) - START 
      SELECT TOP 1 @c_Loadkey = O.Loadkey
      --FROM #tCARTON C
      FROM @tORDERS O
      WHERE O.Loadkey > @c_Loadkey
      GROUP BY O.Loadkey
      ORDER BY O.Loadkey                                              
      --(Wan06) - END

      IF @@ROWCOUNT = 0
      BEGIN
         BREAK
      END

      SET @c_PickSlipNo = ''
      SELECT @c_PickSlipNo = P.PickHeaderKey 
      FROM PICKHEADER P WITH (NOLOCK) 
      WHERE ExternOrderkey = @c_Loadkey
      AND Loadkey = @c_Loadkey

      BEGIN TRAN
      IF @c_PickSlipNo = ''
      BEGIN
         SET @c_Pickslipno = ''  
         EXEC dbo.nspg_GetKey   
               @KeyName     = 'PICKSLIP'
            ,  @fieldlength =  9
            ,  @keystring   = @c_Pickslipno  OUTPUT
            ,  @b_Success   = @b_Success     OUTPUT
            ,  @n_Err       = @n_Err         OUTPUT
            ,  @c_Errmsg    = @c_Errmsg      OUTPUT      
               
         IF @b_success <> 1
         BEGIN
            SET @n_continue = 3  
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 60170   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Executing nspg_GetKey - PICKSLIP. (ispWAVPK05)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            GOTO QUIT_SP
         END
              
         SET @c_Pickslipno = 'P' + @c_Pickslipno    
                   
         INSERT INTO PICKHEADER 
            (
               PickHeaderKey
            ,  ExternOrderkey 
            ,  Orderkey
            ,  PickType
            ,  Zone
            ,  Loadkey
            ,  Wavekey
            ,  Storerkey 
            )
         VALUES 
            (
               @c_PickSlipNo
            ,  @c_Loadkey
            ,  ''
            ,  '0'
            ,  '7'
            ,  @c_Loadkey
            ,  @c_WaveKey
            ,  @c_Storerkey
            )

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3  
            SET @n_err = 60180   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER fail. (ispWAVPK05)' 
            GOTO QUIT_SP
         END
      END

      --(Wan06) - START
      IF NOT EXISTS (SELECT 1 FROM PICKINGINFO P WITH (NOLOCK) WHERE P.PickSlipNo = @c_PickSlipNo)
      BEGIN 
         INSERT INTO PICKINGINFO 
            (
               PickSlipNo
            ,  ScanInDate
            ,  PickerID
            ,  ScanOutDate
            )
         VALUES 
            (
               @c_PickSlipNo
            ,  GETDATE()
            ,  SUSER_NAME()
            ,  NULL
            )

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3  
            SET @n_err = 60190   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKINGINFO fail. (ispWAVPK05)' 
            GOTO QUIT_SP
         END
      END
      --(Wan06) - END

      SET @n_CartonID = 0
      WHILE 1= 1
      BEGIN 
         SELECT TOP 1 @n_CartonID = C.CartonID
                     ,@c_Storerkey= C.Storerkey
                     ,@c_CartonGroup = C.CartonGroup
                     ,@c_Status    = C.[Status]                      --(Wan05)
         FROM #tCARTON C
         WHERE C.Loadkey = @c_Loadkey
         AND   C.CartonID > @n_CartonID
         AND   C.Status <> 'X'                                       --(Wan05)
         --GROUP BY C.CartonID                                       --(Wan05)
         --      ,  C.Storerkey                                      --(Wan05)
         --      ,  C.CartonGroup                                    --(Wan05)
         ORDER BY C.CartonID                                         --(Wan03)
               
         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END
         
         --(Wan05) - START
         IF @c_Status = 'X' 
         BEGIN
            CONTINUE 
         END
         --(Wan05) - END

         IF @c_Status < '9'                                          --(Wan05)
         BEGIN
            UPDATE #tCARTON
               SET Status = '9'
            WHERE CartonID = @n_CartonID
         END

         BEGIN TRAN                                                  --(Wan06)
         IF NOT EXISTS (SELECT 1 FROM PACKHEADER P WITH (NOLOCK) WHERE P.PickSlipNo = @c_PickSlipNo)
         BEGIN 
            INSERT INTO PACKHEADER 
               (
                  PickSlipNo
               ,  Storerkey
               ,  Orderkey
               ,  Loadkey
               ,  CartonGroup
               , [Status]
               )
            VALUES 
               (
                  @c_PickSlipNo
               ,  @c_Storerkey
               ,  ''
               ,  @c_Loadkey
               ,  @c_CartonGroup
               ,  '0'
               )

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3  
               SET @n_err = 60200   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PACKHEADER fail. (ispWAVPK05)' 
               GOTO QUIT_SP
            END
            SET @n_CartonNo = 0
         END

         SET @n_CartonNo = @n_CartonNo + 1
         
         SET @c_LabelNo = ''
         EXEC isp_GenUCCLabelNo_Std
               @cPickSlipNo= @c_PicKSlipno
            ,  @nCartonNo  = @n_CartonNo
            ,  @cLabelNo   = @c_LabelNo OUTPUT
            ,  @b_Success  = @b_Success OUTPUT
            ,  @n_err      = @n_err     OUTPUT
            ,  @c_ErrMsg   = @c_ErrMsg  OUTPUT

         IF @b_Success <> 1
         BEGIN
            SET @n_continue = 3  
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 60210   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Executing isp_GenUCCLabelNo_Std. (ispWAVPK05)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            GOTO QUIT_SP
         END

         IF @b_Debug = 1
         BEGIN
            select  @c_PickSlipNo '@c_PickSlipNo', @n_CartonNo '@n_CartonNo'
         END

         SET @c_RefNo2 = ''
         SELECT @c_RefNo2 = CONVERT(NVARCHAR(30),T.SiteCartonID)
         FROM (
               SELECT D.[Site]
                  ,   D.CartonID
                  ,   SiteCartonID = DENSE_RANK() OVER (PARTITION BY D.[Site] ORDER BY D.CartonID)  
               FROM #tCARTON C 
               JOIN #tCARTONDETAIL D ON (C.CartonID = D.CartonID)
               WHERE C.Loadkey = @c_Loadkey
               AND   D.[Site] <> ''
               ) T
         WHERE T.CartonID = @n_CartonID

         INSERT INTO PACKDETAIL
            (  
               PickSlipNo
            ,  CartonNo
            ,  LabelNo
            ,  LabelLine
            ,  Storerkey
            ,  Sku
            ,  Qty 
            ,  ExpQty
            ,  Refno
            ,  RefNo2
            ) 
         SELECT 
               @c_PickSlipNo
            ,  @n_CartonNo
            ,  @c_LabelNo
            ,  LabelLine = RIGHT ('00000' + CONVERT(NVARCHAR(5), ROW_NUMBER() OVER (ORDER BY MIN(CD.RowID))) , 5)
            ,  CD.Storerkey
            ,  CD.Sku
            ,  0 
            ,  Qty = ISNULL(SUM(CD.Qty),0)
            ,  CD.[Site]
            ,  @c_RefNo2
         FROM #tCARTONDETAIL CD
         WHERE CD.CartonID =  @n_CartonID
         GROUP BY
               CD.Storerkey
            ,  CD.Sku
            ,  CD.[Site]

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3  
            SET @n_err = 60220   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PACKDETAIL fail. (ispWAVPK05)' 
            GOTO QUIT_SP
         END

         --WL01 Start
         IF NOT EXISTS (SELECT 1 FROM PACKINFO (NOLOCK) WHERE Pickslipno = @c_PickSlipNo AND CartonNo = @n_CartonNo)
         BEGIN
            INSERT INTO PackInfo
               (  
                  PickSlipNo
               ,  CartonNo
               ,  [Weight]
               ,  [Cube]
               ,  Qty 
               ) 
            SELECT 
                  @c_PickSlipNo
               ,  @n_CartonNo
               ,  0
               ,  0
               ,  Qty = ISNULL(SUM(CD.Qty),0)
            FROM #tCARTONDETAIL CD
            WHERE CD.CartonID =  @n_CartonID

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3  
               SET @n_err = 60225   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PackInfo fail. (ispWAVPK05)' 
               GOTO QUIT_SP
            END
         END
         --WL01 End

         --SET @c_Pickslipno = ''                                    --(Wan06)  
         EXEC dbo.nspg_GetKey   
               @KeyName     = 'CARTON'
            ,  @fieldlength = 10
            ,  @keystring   = @c_CartonKey   OUTPUT
            ,  @b_Success   = @b_Success     OUTPUT
            ,  @n_Err       = @n_Err         OUTPUT
            ,  @c_Errmsg    = @c_Errmsg      OUTPUT      
               
         IF @b_success <> 1
         BEGIN
            SET @n_continue = 3  
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 60230   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Executing nspg_GetKey - CARTON. (ispWAVPK05)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            GOTO QUIT_SP
         END

         INSERT INTO CARTONLIST
            (  
               CartonKey
            ,  CartonType
            ,  CurrCube
            ,  [Status]
            ,  Seqno
            ) 
         SELECT 
               @c_CartonKey
            ,  C.CartonType
            ,  ISNULL(SUM(CD.PackCube),0.00)
            ,  '9'
            ,  @n_CartonNo
         FROM #tCARTON C
         JOIN #tCARTONDETAIL CD ON C.CartonId = CD.CartonID
         WHERE CD.CartonID =  @n_CartonID
         GROUP BY C.CartonType

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3  
            SET @n_err = 60240  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert CARTONLIST fail. (ispWAVPK05)' 
            GOTO QUIT_SP
         END

         INSERT INTO CARTONLISTDETAIL
            (  
               CartonKey
            ,  Sku
            ,  Qty
            ,  PickDetailkey
            ,  Orderkey
            ,  LabelNo
            ) 
         SELECT 
               @c_CartonKey
            ,  CD.Sku
            ,  CD.Qty
            ,  CD.PickDetailkey
            ,  CD.Orderkey
            ,  @c_LabelNo
         FROM #tCARTONDETAIL CD
         WHERE CD.CartonID =  @n_CartonID

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3  
            SET @n_err = 60250   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert CARTONLISTDETAIL fail. (ispWAVPK05)' 
            GOTO QUIT_SP
         END

         SET @c_PickDetailKey = ''
         WHILE 1 = 1
         BEGIN
            SELECT TOP 1 
                  @c_PickDetailKey = CD.PickDetailkey 
            FROM #tCARTONDETAIL CD
            WHERE CD.CartonID = @n_CartonID
            AND   CD.PickDetailkey > @c_PickDetailKey
            ORDER BY CD.PickDetailkey 

            IF @@ROWCOUNT = 0
            BEGIN
               BREAK
            END

            UPDATE PICKDETAIL  
               SET CaseID = @c_LabelNo
                  ,Trafficcop = NULL
                  ,EditWho = SUSER_NAME()
                  ,EditDate= GETDATE()
            WHERE Pickdetailkey = @c_PickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3  
               SET @n_err = 60260  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE PICKDETAIL fail. (ispWAVPK05)' 
          
               GOTO QUIT_SP
            END
         END

         --WL01 Start - Update Weight, Cube into Packinfo
         SELECT @n_CtnWeight = CTNINFO.CartonWeight + SUM(PKD.ExpQty * SKU.STDGROSSWGT), 
                @n_CtnCube   = CTNINFO.[Cube]
         FROM PACKDETAIL PKD (NOLOCK)  
         JOIN SKU (NOLOCK) ON PKD.StorerKey = SKU.StorerKey AND PKD.Sku = SKU.Sku
         JOIN (
            SELECT PKH.Pickslipno, PKD.Cartonno, CL.CartonType, CZ.CartonWeight, CZ.[Cube]
            FROM PACKHEADER PKH (NOLOCK)
            JOIN PACKDETAIL PKD (NOLOCK) ON PKH.PickSlipNo = PKD.PickSlipNo
            JOIN PICKDETAIL PD (NOLOCK) ON PKD.LabelNo = PD.CaseID 
                                           AND PKD.Storerkey = PD.Storerkey
                                           AND PKD.Sku = PD.Sku                                                            
            JOIN CARTONLISTDETAIL CLD (NOLOCK) ON PD.PickDetailKey = CLD.PickDetailKey               
            JOIN CARTONLIST CL (NOLOCK) ON CLD.CartonKey = CL.CartonKey
            JOIN CARTONIZATION CZ (NOLOCK) ON CL.CartonType = CZ.CartonType AND PKH.CartonGroup = CZ.CartonizationGroup --CL.CartonType = CZ.CartonizationKey                 
            WHERE PKH.Pickslipno = @c_PickSlipNo AND PKD.CartonNo = @n_CartonNo
            GROUP BY PKH.Pickslipno, PKD.Cartonno, CL.CartonType, CZ.CartonWeight, CZ.[Cube]
            ) AS CTNINFO ON PKD.PickSlipNo = CTNINFO.Pickslipno AND PKD.CartonNo = CTNINFO.Cartonno
         WHERE PKD.PickSlipNo = @c_PickSlipNo AND PKD.CartonNo = @n_CartonNo
         GROUP BY PKD.Pickslipno, PKD.Cartonno, CTNINFO.CartonWeight, CTNINFO.[Cube]
         
         --select @c_PickSlipNo,@n_CartonNo,@n_CtnWeight,@n_CtnCube  
         --INSERT INTO TRACEINFO(TraceName, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5)
         --SELECT 'ispWAVPK05','Pickslipno','CartonNo','LabelNo','Weight','Cube',@c_PickSlipNo,@n_CartonNo,@c_LabelNo,@n_CtnWeight,@n_CtnCube

         UPDATE PACKINFO WITH (ROWLOCK)
         SET [Weight] = @n_CtnWeight,
             [Cube]   = @n_CtnCube
         WHERE Pickslipno = @c_PickSlipNo
         AND CartonNo = @n_CartonNo
         --WL01 End - Update Weight, Cube into Packinfo     

         WHILE @@TRANCOUNT > 0 
         BEGIN
            COMMIT TRAN
         END
      END

      --(Wan06) - START
      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END
      --(Wan06) - END
   END

   --------------------------------------------------------------------------------
   -- CREATE CARTON, CARTONLIST, PICKHEADER, PACKHEADER, PACKDETAIL, PACKINFO (END)
   --------------------------------------------------------------------------------
  
QUIT_SP:

   --(Wan05) - START

   IF OBJECT_ID('tempdb..#tPICKDETAIL','u') IS NOT NULL
   DROP TABLE #tPICKDETAIL;

   IF OBJECT_ID('tempdb..#tCARTON','u') IS NOT NULL
   DROP TABLE #tCARTON;

   IF OBJECT_ID('tempdb..#tCARTONDETAIL','u') IS NOT NULL
   DROP TABLE #tCARTONDETAIL;
   --(Wan05) - END


   IF @n_Continue=3  -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT > 0
      BEGIN
         ROLLBACK TRAN
      END

      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispWAVPK05'    
      RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      
    END
    ELSE
    BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
    END 

    WHILE @@TRANCOUNT < @n_StartTCnt
    BEGIN
      BEGIN TRAN
    END
   
END -- Procedure

GO