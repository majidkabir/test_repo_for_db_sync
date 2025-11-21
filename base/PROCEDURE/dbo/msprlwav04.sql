SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: mspRLWAV04                                          */
/* Creation Date: 19-Oct-2024                                            */
/* Copyright: MAERSK                                                     */
/* Written by: USH022                                                    */
/*                                                                       */
/* Purpose: UWP-24680 - [FCR-774] [HUSQ] TM wave release rules           */
/*                                                                       */
/* Called By: Wave                                                       */
/*                                                                       */
/* GitHub Version: 2.0                                                   */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date           Author    Ver   Purposes                               */
/* 19-Oct-2024    USH022    1.0   UWP-24680                              */
/* 16-Nov-2024    SHONG     1.1   Revise coding logic for multiple issues*/
/* 18-Nov-2024    SHONG     1.2   Revise Task Message                    */
/* 19-Nov-2024    SHONG     1.3   Missing torelance for non-parcel       */
/* 04-Dec-2024    SHONG     1.4   Set Task Status Priority by OrderGroup */
/* 10-Dec-2024    SHONG01   1.5   Revise VAS Flag logic                  */
/* 27-Jan-2025    USH022-01 1.6   Exclude LOT for ASTCPK tasktype        */
/*                                Ticket-UWP-28865                       */
/*************************************************************************/
CREATE   PROC [dbo].[mspRLWAV04]
   @c_WaveKey NVARCHAR(10)
 , @b_Success INT           OUTPUT
 , @n_Err     INT           OUTPUT
 , @c_ErrMsg  NVARCHAR(250) OUTPUT
 , @b_debug   INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
           @n_StartTCnt          INT   = @@TRANCOUNT
         , @n_Continue           INT   = 1

         , @c_Facility           NVARCHAR(5)  = ''
         , @c_Loadkey            NVARCHAR(10) = ''
         , @c_Consigneekey       NVARCHAR(15) = ''
         , @c_C_Zip              NVARCHAR(18) = ''
         , @c_OrderKey_Last      NVARCHAR(10) = ''
         , @c_ParcelType         NVARCHAR(30) = ''
         , @c_ParcelType_Last    NVARCHAR(30) = ''
         , @c_OtherReference     NVARCHAR(10) = ''

         , @c_PickDetailkey      NVARCHAR(10) = ''
         , @c_OrderKey           NVARCHAR(10) = ''
         , @c_OrderLineNumber    NVARCHAR(5)  = ''
         , @c_Storerkey          NVARCHAR(15) = ''
         , @c_Sku                NVARCHAR(20) = ''
         , @c_Sku_Last           NVARCHAR(20) = ''
         , @c_SkuClass           NVARCHAR(10) = ''
         , @c_SkuClass_Last      NVARCHAR(10) = ''
         , @c_SerialNoCapture    NVARCHAR(1)  = ''
         , @n_StdGrossWgt        FLOAT        = 0.00
         , @n_PackCube           FLOAT        = 0.00
         , @c_UOM                NVARCHAR(10) = ''
         , @c_Lot                NVARCHAR(10) = ''
         , @c_FromLoc            NVARCHAR(10) = ''
         , @c_FromLogicalLoc     NVARCHAR(10) = ''
         , @c_ID                 NVARCHAR(18) = ''
         , @c_LocAisle           NVARCHAR(10) = ''
         , @n_Qty                INT          = 0
         , @n_UOMQty             INT          = 0

         , @c_PickSlipNo         NVARCHAR(10) = ''
         , @c_PickHeaderKey      NVARCHAR(10) = ''

         , @c_TaskDetailKey      NVARCHAR(10) = ''
         , @c_TaskType           NVARCHAR(10) = ''
         , @c_TaskType_Last      NVARCHAR(10) = ''
         , @c_ToLoc              NVARCHAR(10) = ''
         , @c_ToLogicalLoc       NVARCHAR(10) = ''
         , @c_PickMethod         NVARCHAR(10) = ''
         , @c_Message01          NVARCHAR(20) = ''
         , @c_Message02          NVARCHAR(20) = ''
         , @c_Message03          NVARCHAR(20) = ''
         , @c_GroupKey           NVARCHAR(10) = ''
         , @c_GroupKey_Last      NVARCHAR(10) = ''
         , @c_SourceType         NVARCHAR(10) = 'mspRLWAV04'
         , @c_Priority           NVARCHAR(10) = '9'
         , @c_TaskStatus         NVARCHAR(10) = '0'
         , @c_TaskStatus_FPK     NVARCHAR(10) = '0'
         , @c_LinkTaskToPick_SQL NVARCHAR(MAX)= ''

         , @n_NoOfPallet_df      INT          = 0
         , @n_MaxCube_df         FLOAT        = 0.00
         , @n_MaxHeight_df       FLOAT        = 0.00
         , @n_MaxWeight_df       FLOAT        = 0.00
         , @c_OneBrand_df        NVARCHAR(10) = ''
         , @c_PalletType_df      NVARCHAR(10) = ''

         , @n_NoOfPallet         INT          = 0
         , @n_MaxCube            FLOAT        = 0.00
         , @n_MaxHeight          FLOAT        = 0.00
         , @n_MaxWeight          FLOAT        = 0.00
         , @c_OneBrand           NVARCHAR(10) = ''
         , @c_PalletType         NVARCHAR(10) = ''

         , @b_VASFlag            BIT          = ''
         , @b_NonParcel          BIT          = 0
         , @n_OrderCnt           INT          = 0
         , @n_MaxOrderPerGroup   INT          = 5
         , @n_NoOfOrderPerGrp    INT          = 0
         , @c_BoxType            NVARCHAR(50) = ''
         , @c_ParcelSize         NVARCHAR(50) = ''
         , @c_ParcelSize_Last    NVARCHAR(50) = ''
         , @n_Cube_ORD           FLOAT        = 0.00
         , @n_Cube               FLOAT        = 0.00
         , @n_Height             FLOAT        = 0.00
         , @n_Weight             FLOAT        = 0.00
         , @n_Tolerance          FLOAT        = 0.00
         , @n_Tolerance_T        FLOAT        = 0.00
         , @n_TotalCube          FLOAT        = 0.00
         , @n_TotalWeight        FLOAT        = 0.00
         , @n_TrolleyCube        FLOAT        = 0.00

         , @n_MaxOrdPerBld       INT          = 0
         , @n_MaxOrdPerBld01     INT          = 0
         , @n_MaxOrdPerBld02     INT          = 0
         , @n_MaxOrdPerBld03     INT          = 0
         , @n_MaxOrdPerBld04     INT          = 0
         , @n_MaxOrdPerBld05     INT          = 0
         , @c_FirstOrderKey      NVARCHAR(10) = ''
         , @b_InsertTask         BIT          = 0            --USH022-01
         , @c_ID_Last            NVARCHAR(18) = ''
         , @c_Loc                NVARCHAR(10) = ''
         , @c_Loc_Last           NVARCHAR(10) = ''           --USH022-01

      DECLARE @n_Capacity INT = 0,
              @n_MaxSKU   INT = 0,
              @n_RowID    INT = 0,
              @n_TotalSKU INT = 0

   DECLARE @CUR_PCK        CURSOR
         , @CUR_TSK        CURSOR

   SET @b_success = 0
   SET @n_err = 0
   SET @c_errmsg = ''

   IF @@TRANCOUNT = 0
      BEGIN TRAN

   IF EXISTS ( SELECT 1 FROM TaskDetail td (NOLOCK)
               WHERE td.Wavekey = @c_Wavekey
               AND   td.Sourcetype = @c_SourceType
               AND   td.Tasktype IN ('FPK','ASTCPK')
               AND   td.[Status] NOT IN ('X')
             )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 85010
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err) + ': Task has been released.(mspRLWAV04)'
      GOTO RETURN_SP;
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      SELECT TOP 1
              @c_Storerkey  = OH.Storerkey
            , @c_Facility   = OH.Facility
            , @c_OrderKey   = OH.OrderKey
            , @c_ParcelType = ISNULL(OH.UserDefine10,'')
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      WHERE WD.Wavekey = @c_Wavekey
      ORDER BY ISNULL(OH.UserDefine10,'')

      -- Check if Orders.Userdefined10 is NULL or blank
      IF @c_ParcelType = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 85020
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err) +': Missing Order Type - '+@c_OrderKey+
         ', You are not allow to Release Wave: '+ @c_Wavekey + '. (mspRLWAV04)'
         GOTO RETURN_SP;
      END
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      IF OBJECT_ID('tempdb..#TMP_CODELKUP','u') IS NOT NULL
      BEGIN
         DROP TABLE #TMP_CODELKUP;
      END

      CREATE TABLE #TMP_CODELKUP
      (  ListName    NVARCHAR(10)   NOT NULL    DEFAULT ('')
      ,  Code        NVARCHAR(10)   NOT NULL    DEFAULT ('')
      ,  Short       NVARCHAR(10)   NOT NULL    DEFAULT ('')
      ,  UDF01       NVARCHAR(50)   NOT NULL    DEFAULT ('')
      ,  UDF02       NVARCHAR(50)   NOT NULL    DEFAULT ('')
      ,  UDF03       NVARCHAR(50)   NOT NULL    DEFAULT ('')
      ,  UDF04       NVARCHAR(50)   NOT NULL    DEFAULT ('')
      ,  UDF05       NVARCHAR(50)   NOT NULL    DEFAULT ('')
      ,  Storerkey   NVARCHAR(15)   NOT NULL    DEFAULT ('')
      ,  Code2       NVARCHAR(30)   NOT NULL    DEFAULT ('')
      )

      INSERT INTO #TMP_CODELKUP
         (ListName, Code, Short, UDF01, UDF02, UDF03, UDF04, UDF05, Storerkey,Code2)
      SELECT ListName, Code
            , Short = ISNULL(Short,'')
            , UDF01, UDF02
            , IIF(ISNUMERIC(UDF03)= 1, UDF03,'0.00')
            , IIF(ISNUMERIC(UDF04)= 1, UDF04,'0.00')
            , UDF05
            , Storerkey,Code2
      FROM CODELKUP (NOLOCK)
      WHERE ListName  = 'HUSQPKTYPE'
      AND   Storerkey = @c_Storerkey

   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- Check if all Orders have the same Userdefined10 (Parcel/Non-Parcel)
      DECLARE @n_OrderTypeCount INT
      DECLARE @n_OrderKeyCount INT, @n_InvalidParcelType INT = 0, @n_UDF10_AS_UNKNOWN INT = 0;;

      SELECT @n_OrderTypeCount = COUNT(DISTINCT ISNULL(cl.UDF01,''))
           , @n_OrderKeyCount  = COUNT(O.OrderKey)
           , @n_InvalidParcelType = MAX(CASE WHEN cl.ListName IS NULL THEN 1 ELSE 0 END)
           , @n_UDF10_AS_UNKNOWN =	MAX(CASE WHEN O.UserDefine10 = 'UNKNOWN' THEN 1 ELSE 0 END)
      FROM Orders O (NOLOCK)
      JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = O.OrderKey
      LEFT OUTER JOIN #TMP_CODELKUP cl ON  cl.listName = 'HUSQPKTYPE'
                                             AND cl.StorerKey = O.Storerkey
                                             AND cl.Short = o.Userdefine10
      WHERE
      WD.WaveKey = @c_WaveKey;

      IF @n_OrderTypeCount > 1
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 85030
         SET @c_errmsg='NSQL'+LTRIM(RTRIM(CONVERT(NVARCHAR(5),@n_err))) +
         ':Mixed Order Type, You are not allow to Release Wave: '+ @c_Wavekey + '. (mspRLWAV04)'
         GOTO RETURN_SP;
      END

      IF @n_UDF10_AS_UNKNOWN > 0
         BEGIN
         SET @n_Continue = 3
         SET @n_Err = 85030
         SET @c_errmsg='NSQL'+LTRIM(RTRIM(CONVERT(NVARCHAR(5),@n_err))) +
         ':Unknown Order type, You are not allow to Release Wave: '+ @c_Wavekey + '. Please correct the order type (mspRLWAV04)'
         GOTO RETURN_SP;
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- Check if Orders.Userdefined10 is not in the Codelkup for HUSQPKTYPE
      IF @n_InvalidParcelType > 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 85040
         SET @c_errmsg='NSQL'+LTRIM(RTRIM(CONVERT(NVARCHAR(5),@n_err))) +
         ':Incorrect Order Type,'+ @c_OrderKey +' You are not allow to Release Wave. (mspRLWAV04)'
         GOTO RETURN_SP;
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- Order count validation for WaveKey
      DECLARE @c_Buildparmkey NVARCHAR(10);
      select top 1 @c_Buildparmkey = bwl.Buildparmkey
      FROM BuildWaveLog bwl(NOLOCK)
      JOIN BuildWaveDetailLog bwdl (NOLOCK) ON bwdl.BatchNo = bwl.BatchNo
      JOIN BuildParm bp (NOLOCK) ON bp.Buildparmkey = bwl.Buildparmkey
      where bwdl.Wavekey = @c_WaveKey;

      SELECT @n_MaxOrdPerBld01= CASE WHEN BP.Restriction01 = '1_MaxOrderPerBuild' THEN BP.RestrictionValue01  ELSE 0 END
      ,@n_MaxOrdPerBld02= CASE WHEN BP.Restriction02 = '1_MaxOrderPerBuild' THEN BP.RestrictionValue02  ELSE 0 END
      ,@n_MaxOrdPerBld03= CASE WHEN BP.Restriction03 = '1_MaxOrderPerBuild' THEN BP.RestrictionValue03  ELSE 0 END
      ,@n_MaxOrdPerBld04= CASE WHEN BP.Restriction04 = '1_MaxOrderPerBuild' THEN BP.RestrictionValue04  ELSE 0 END
      ,@n_MaxOrdPerBld05= CASE WHEN BP.Restriction05 = '1_MaxOrderPerBuild' THEN BP.RestrictionValue05  ELSE 0 END
      FROM BUILDPARM BP WITH (NOLOCK)
      WHERE BP.BuildParmKey = @c_BuildParmKey

      SET @n_MaxOrdPerBld= @n_MaxOrdPerBld01
      IF @n_MaxOrdPerBld = 0 SET @n_MaxOrdPerBld = @n_MaxOrdPerBld02
      IF @n_MaxOrdPerBld = 0 SET @n_MaxOrdPerBld = @n_MaxOrdPerBld03
      IF @n_MaxOrdPerBld = 0 SET @n_MaxOrdPerBld = @n_MaxOrdPerBld04
      IF @n_MaxOrdPerBld = 0 SET @n_MaxOrdPerBld = @n_MaxOrdPerBld05

      IF(@n_OrderKeyCount > @n_MaxOrdPerBld)
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 85050
         SET @c_errmsg='NSQL'+ LTRIM(RTRIM(CONVERT(NVARCHAR(5), @n_err))) +
         ': Number of Orders in this wave has been reached system limitation = '+
         LTRIM(RTRIM(CONVERT(VARCHAR, @n_MaxOrdPerBld)))+' Orders: '+'. (mspRLWAV04)'
         GOTO RETURN_SP;
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- Check if any SKU is missing dimensions or if any dimension is '0'
      DECLARE @c_dimention INT;
      SET @c_dimention = 0;
      SET @c_SKU = '';
      SELECT @c_dimention = SUM(P.WidthUOM3 * P.LengthUOM3 * P.HeightUOM3), @c_Sku = S.Sku
      FROM PACK P (NOLOCK)
      JOIN SKU S (NOLOCK) ON S.PackKey = P.PACKKey
      JOIN ORDERDETAIL OD (NOLOCK) ON OD.Storerkey = S.StorerKey
      AND OD.SKU = S.SKU
      JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = OD.OrderKey
      WHERE WD.WAVEKey = @c_WaveKey
      GROUP BY P.PackKey, S.Sku
      HAVING SUM(P.WidthUOM3 * P.LengthUOM3 * P.HeightUOM3) = 0

      IF(@c_dimention = 0 AND @c_SKU <> '')
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 85060
         SET @c_errmsg='NSQL'+LTRIM(RTRIM(CONVERT(NVARCHAR(5),@n_err))) +
         ':Missing SKU Dimension -'+@c_Sku+', You are not allow to Release Wave:'+ @c_Wavekey +'. (mspRLWAV04)'
         GOTO RETURN_SP;
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS(SELECT 1 FROM WAVEDETAIL WD (NOLOCK)
            LEFT OUTER JOIN MBOLDETAIL MD (NOLOCK) ON WD.OrderKey = MD.OrderKey
            LEFT OUTER JOIN MBOL M (NOLOCK) ON MD.MBOlKey =  M.MbolKey
            WHERE WD.WaveKey = @c_WaveKey
            AND M.MbolKey IS NULL)
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 85090
         SET @c_errmsg='NSQL'+LTRIM(RTRIM(CONVERT(NVARCHAR(5),@n_err))) +
         ':Shipping Reference not being generated, You are not allow to Release Wave: '+
         @c_Wavekey +'. (mspRLWAV04)'
         GOTO RETURN_SP;
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS(SELECT 1 FROM WAVEDETAIL WD (NOLOCK)
            LEFT OUTER JOIN LoadPlanDetail LD (NOLOCK) ON WD.OrderKey = LD.OrderKey
            WHERE WD.WaveKey = @c_WaveKey
            AND LD.LoadKey IS NULL)
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 85100
         SET @c_errmsg='NSQL'+LTRIM(RTRIM(CONVERT(NVARCHAR(5),@n_err))) +
         ':Load not being generated, You are not allow to Release Wave: '+
         @c_Wavekey +'. (mspRLWAV04)'
         GOTO RETURN_SP;
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @c_OtherReference = '';

      IF EXISTS(SELECT 1 FROM MBOL M (NOLOCK)
            JOIN MBOLDETAIL MD (NOLOCK) ON MD.MBOlKey =  M.MbolKey
            JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = MD.OrderKey
            LEFT OUTER JOIN LOC loc (NOLOCK) ON loc.Loc = M.OtherReference AND loc.Facility = @c_Facility
            WHERE WD.WaveKey = @c_WaveKey
            AND (M.OtherReference = '' OR M.OtherReference IS NULL OR LOC.LOC IS NULL))
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 85070
         SET @c_errmsg='NSQL'+LTRIM(RTRIM(CONVERT(NVARCHAR(5),@n_err))) +
         ':Missing marshalling assignment - '+@c_WaveKey+', You are not allow to Release Wave: '+
         @c_Wavekey +'. (mspRLWAV04)'
         GOTO RETURN_SP;
      END


      SELECT TOP 1
         @c_OtherReference = M.OtherReference
      FROM MBOL M (NOLOCK)
      JOIN MBOLDETAIL MD (NOLOCK) ON MD.MBOlKey =  M.MbolKey
      JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = MD.OrderKey
      LEFT OUTER JOIN LOC loc (NOLOCK) ON loc.Loc = M.OtherReference AND loc.Facility = @c_Facility
      WHERE WD.WaveKey = @c_WaveKey
      AND (M.OtherReference > '' AND M.OtherReference IS NOT NULL)

      IF EXISTS(SELECT 1
            FROM MBOL M (NOLOCK)
            JOIN MBOLDETAIL MD (NOLOCK) ON MD.MBOlKey =  M.MbolKey
            JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = MD.OrderKey
            JOIN LOC loc (NOLOCK) ON loc.Loc = M.OtherReference AND loc.Facility = @c_Facility
            WHERE WD.WaveKey <> @c_WaveKey
            AND M.OtherReference = @c_OtherReference
            AND M.Status <> '9'
            AND (M.OtherReference > '' AND M.OtherReference IS NOT NULL))
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 85080
         SET @c_errmsg='NSQL'+LTRIM(RTRIM(CONVERT(NVARCHAR(5),@n_err))) +
         ':Marshalling lanes are used for different waves, You are not allow to Release Wave: '+
         @c_Wavekey +'. (mspRLWAV04)'
         GOTO RETURN_SP;
      END
   END


   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF OBJECT_ID('tempdb..#PICKDETAIL_WIP') IS NOT NULL
         DROP TABLE #PICKDETAIL_WIP

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

   --Initialize Pickdetail work in progress staging table
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      EXEC isp_CreatePickdetail_WIP
            @c_Loadkey               = ''
         ,  @c_Wavekey               = @c_wavekey
         ,  @c_WIP_RefNo             = @c_SourceType
         ,  @c_PickCondition_SQL     = ''
         ,  @c_Action                = 'I'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
         ,  @c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
         ,  @b_Success               = @b_Success OUTPUT
         ,  @n_Err                   = @n_Err     OUTPUT
         ,  @c_ErrMsg                = @c_ErrMsg  OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END
      ELSE
      BEGIN
         UPDATE #PICKDETAIL_WIP
         SET #PICKDETAIL_WIP.Taskdetailkey = ''
         FROM #PICKDETAIL_WIP
         LEFT JOIN TASKDETAIL TD (NOLOCK) ON  TD.Taskdetailkey = #PICKDETAIL_WIP.Taskdetailkey
                                          AND TD.Sourcetype = @c_SourceType
                                          AND TD.Tasktype IN ('FPK','ASTCPK')
                                          AND TD.PickDetailKey = #PICKDETAIL_WIP.PickDetailKey
                                          AND TD.Status <> 'X'
         WHERE TD.Taskdetailkey IS NULL
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN

      SELECT @n_MaxCube_df      = IIF(ISNUMERIC(ST.SUSR1)=1,CONVERT(FLOAT,ST.SUSR1),0.00)
            ,@n_MaxHeight_df    = IIF(ISNUMERIC(ST.SUSR2)=1,CONVERT(FLOAT,ST.SUSR2),0.00)
            ,@n_MaxWeight_df    = IIF(ISNUMERIC(ST.SUSR3)=1,CONVERT(FLOAT,ST.SUSR3),0.00)
            ,@c_OneBrand_df     = ST.SUSR4
            ,@n_NoOfPallet_df   = IIF(ISNULL(ST.CreditLimit,'0') IN ('0',''),2,1)
            ,@c_PalletType_df   = ISNULL(ST.Pallet,'')
      FROM STORER ST (NOLOCK)
      WHERE ST.[Type] = '2'
      AND   ST.ConsigneeFor = @c_Storerkey
      AND   ST.Storerkey = '0000000001'

      -- (SHONG01)
      SET @b_VASFlag = 0
      IF EXISTS(SELECT 1
               FROM dbo.STORERSODEFAULT SOD (NOLOCK)
               WHERE SOD.Storerkey = '0000000001'
               AND SOD.OrderType = 'Y')
      BEGIN
         SET @b_VASFlag = 1
      END

      IF OBJECT_ID('tempdb..#TMP_BRAND','u') IS NOT NULL
      BEGIN
         DROP TABLE #TMP_BRAND;
      END

      CREATE TABLE #TMP_BRAND
      (  RowID       INT            NOT NULL    IDENTITY(1,1)     PRIMARY KEY
      ,  GroupKey    NVARCHAR(10)   NOT NULL    DEFAULT ('')
      ,  OrderKey    NVARCHAR(10)   NOT NULL    DEFAULT ('')
      ,  Class       NVARCHAR(10)   NOT NULL    DEFAULT ('')
      ,  TotalCube   FLOAT          NOT NULL    DEFAULT ('')
      ,  TotalWeight FLOAT          NOT NULL    DEFAULT ('')
      )
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @CUR_PCK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.PickdetailKey
            ,PD.OrderKey
            ,PD.OrderLineNumber
            ,PD.Storerkey
            ,PD.Sku
            ,PD.Lot
            ,PD.Loc
            ,PD.ID
            ,PD.UOM
            ,PD.Qty
            ,S.Class
            ,S.SerialNoCapture
            ,S.StdGrossWgt
            ,PackCube = P.WidthUOM3 * P.LengthUOM3 * P.HeightUOM3
            ,L.LogicalLocation
            ,L.LocAisle
            ,LoadKey = ISNULL(OH.Loadkey,'')
            ,OH.Consigneekey
            ,OH.C_Zip
            ,OH.Userdefine10
      FROM #PickDetail_WIP PD (NOLOCK)
      JOIN ORDERS     OH (NOLOCK) ON OH.OrderKey = PD.OrderKey
      JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = OH.OrderKey
      JOIN SKU        S  (NOLOCK) ON  S.Storerkey = PD.Storerkey
                                  AND S.Sku = PD.Sku
      JOIN PACK       P  (NOLOCK) ON  P.Packkey = S.Packkey
      JOIN LOC        L  (NOLOCK) ON PD.Loc = L.Loc
      WHERE WD.Wavekey  = @c_WaveKey
      AND   PD.[Status] < '5'
      AND   PD.TaskDetailKey = ''
      AND   PD.UOM IN ('1','6')
      ORDER BY CASE WHEN ISNULL(OH.OrderGroup,'') = '' THEN '999999' ELSE OH.OrderGroup END
             , OH.DeliveryDate
             , PD.OrderKey
             , PD.UOM
             , CASE WHEN PD.UOM = '6' THEN PD.Loc ELSE '' END             --USH022-01
             , L.LogicalLocation
             , CASE WHEN PD.UOM = '6' THEN PD.ID ELSE '' END              --USH022-01
             , S.Class
             , S.Sku
             , PD.PickDetailKey

      OPEN @CUR_PCK

      FETCH NEXT FROM @CUR_PCK INTO @c_PickdetailKey
                                 ,  @c_OrderKey
                                 ,  @c_OrderLineNumber
                                 ,  @c_Storerkey
                                 ,  @c_Sku
                                 ,  @c_Lot
                                 ,  @c_FromLoc
                                 ,  @c_ID
                                 ,  @c_UOM
                                 ,  @n_Qty
                                 ,  @c_SkuClass
                                 ,  @c_SerialNoCapture
                                 ,  @n_StdGrossWgt
                                 ,  @n_PackCube
                                 ,  @c_FromLogicalLoc
                                 ,  @c_LocAisle
                                 ,  @c_Loadkey
                                 ,  @c_Consigneekey
                                 ,  @c_C_Zip
                                 ,  @c_ParcelType
      WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
      BEGIN
         IF @c_FirstOrderKey = '' AND @c_ParcelType='Non-Parcel'
         BEGIN
            SET @c_FirstOrderKey = @c_OrderKey
         END

         SET @c_TaskStatus_FPK = 'S'
         SET @c_TaskStatus = 'S'

         IF @c_FirstOrderKey = @c_OrderKey
         BEGIN
            SET @c_TaskStatus_FPK = '0'
            SET @c_TaskStatus = '0'
         END

         IF @c_OrderKey <> @c_OrderKey_Last
         BEGIN
            SET @c_PickSlipNo = ''

            SELECT @c_PickSlipNo = ISNULL(ph.PickHeaderKey,'')
            FROM PICKHEADER ph (NOLOCK)
            WHERE ph.OrderKey = @c_OrderKey
            AND ph.[Zone] = 'LP'

            IF @c_PickSlipNo = ''
            BEGIN
               SET @b_success = 1
               EXECUTE nspg_getkey
                       @KeyName   = 'PICKSLIP'
                     , @fieldlength = 9
                     , @KeyString   = @c_PickSlipNo      OUTPUT
                     , @b_success   = @b_success         OUTPUT
                     , @n_err       = @n_err             OUTPUT
                     , @c_errmsg    = @c_errmsg          OUTPUT

               IF @b_success = 0
               BEGIN
                  SET @n_Continue = 3
               END

               IF @n_Continue = 1
               BEGIN
                  SET @c_PickSlipNo = N'P' + @c_PickSlipNo

                  INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, Loadkey, [Zone], Wavekey, StorerKey)
                  VALUES (@c_PickSlipNo, @c_OrderKey, @c_Loadkey, @c_Loadkey, 'LP', @c_Wavekey, @c_Storerkey)

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3
                  END
               END
            END

            IF @n_Continue = 1
            BEGIN
               SET @n_OrderCnt     = @n_OrderCnt + 1
               IF @b_NonParcel = 1
               BEGIN
                  SET @c_GroupKey = ''
               END

               SET @n_MaxCube      = @n_MaxCube_df
               SET @n_MaxHeight    = @n_MaxHeight_df
               SET @n_MaxWeight    = @n_MaxWeight_df
               SET @c_OneBrand     = @c_OneBrand_df
               SET @n_NoOfPallet   = @n_NoOfPallet_df  -- Setup 2 for default storer
               SET @c_PalletType   = @c_PalletType_df

               IF @c_Consigneekey <> ''
               BEGIN
                  SELECT @n_MaxCube   = IIF(ISNUMERIC(ST.SUSR1)=1,CONVERT(FLOAT,ST.SUSR1),@n_MaxCube_df)
                        ,@n_MaxHeight = IIF(ISNUMERIC(ST.SUSR2)=1,CONVERT(FLOAT,ST.SUSR2),@n_MaxHeight_df)
                        ,@n_MaxWeight = IIF(ISNUMERIC(ST.SUSR3)=1,CONVERT(FLOAT,ST.SUSR3),@n_MaxWeight_df)
                        ,@c_OneBrand  = IIF(ST.SUSR4 IS NULL,@c_OneBrand_df,ST.SUSR4)
                        ,@n_NoOfPallet= IIF(ISNULL(ST.CreditLimit,'0') IN ('0',''),2,1)
                        ,@c_PalletType= IIF(ST.Pallet IN ('',NULL),@c_PalletType_df,ST.Pallet)
                  FROM ORDERS OH (NOLOCK)
                  JOIN STORER ST (NOLOCK) ON  ST.Address1 = OH.ConsigneeKey
                                          AND ST.Zip      = OH.C_Zip
                                          AND ST.ConsigneeFor = OH.Storerkey
                  WHERE OH.OrderKey = @c_OrderKey
                  AND OH.ConsigneeKey <> ''
                  AND ST.[Type] = '2'
               END

               IF EXISTS(SELECT 1
                        FROM dbo.STORERSODEFAULT SOD (NOLOCK)
                        JOIN dbo.STORER S (NOLOCK) ON SOD.StorerKey = S.StorerKey
                                       AND S.address1 = @c_ConsigneeKey
                                       AND S.Zip = @c_C_Zip
                                       AND S.[Type] = '2'
                        WHERE SOD.OrderType = 'Y')
               BEGIN
                  SET @b_VASFlag = 1
               END

               IF @n_Tolerance = 0.00
               BEGIN
                  SET @n_Tolerance = 100.00
                  SELECT @n_Tolerance = IIF(ISNUMERIC(cl.UDF05)=1,CONVERT(FLOAT,cl.UDF05),100.00)
                  FROM CODELKUP cl(NOLOCK)
                  WHERE cl.LISTNAME ='HUSQ_MHE'
                  AND cl.Storerkey = @c_Storerkey
                  AND cl.Code ='PALL_MHE'
               END

               SET @n_MaxCube   = @n_MaxCube   * (@n_Tolerance / 100.00) * @n_NoOfPallet
               SET @n_MaxWeight = @n_MaxWeight * (@n_Tolerance / 100.00) * @n_NoOfPallet
            END
         END

         IF @n_Continue = 1
         BEGIN
            SET @n_UOMQty = @n_Qty
            SET @c_ToLoc = ''
            SET @c_Message01 = ''
            SET @c_Message02 = ''
            SET @c_Message03 = ''
            SET @c_Loc = @c_FromLoc;                    --USH022-01
            SET @b_InsertTask = 0

            IF @c_UOM = '1'
            BEGIN
               SET @b_InsertTask = 1;
               SET @c_TaskType  = 'FPK'
               SET @c_PickMethod= 'FP'
               SET @c_ToLoc = @c_OtherReference
               SET @c_LinkTaskToPick_SQL = 'PICKDETAIL.OrderKey = @c_OrderKey AND PICKDETAIL.UOM = @c_UOM' --USH022-01

               SELECT @n_Height = IIF(ISNUMERIC(la.Lottable11)= 1,CONVERT(FLOAT,la.Lottable11),0.00)
               FROM LOTATTRIBUTE la (NOLOCK)
               WHERE la.Lot = @c_Lot

               SELECT @n_Weight = @n_Qty * @n_StdGrossWgt

              IF @c_PalletType <> 'CHEP'            SET @c_ToLoc = 'DNVAS01'
              IF @n_Height    > @n_MaxHeight        SET @c_ToLoc = 'DNVAS01'
              IF @n_Weight    > @n_MaxWeight        SET @c_ToLoc = 'DNVAS01'
              IF @b_VASFlag = 1                     SET @c_ToLoc = 'DNVAS01'
              IF @c_SerialNoCapture IN ('1','3') SET @c_ToLoc = 'DNVAS01'

               SET @c_Message01 = @c_PalletType
               SET @c_Message02 = @n_MaxHeight
               SET @c_Message03 = @n_NoOfPallet
               SET @c_GroupKey  = @c_LocAisle
               --SET @c_TaskStatus = @c_TaskStatus_FPK
            END
            ELSE IF @c_UOM = '6' AND
              (@c_ORderkey <> @c_Orderkey_Last OR @c_Loc <> @c_Loc_Last OR @c_ID <> @c_ID_Last --USH022-01
              OR (@c_Sku <> @c_Sku_last AND @c_Skuclass <> @c_SkuClass_last)           --USH022-01
              )
            BEGIN
               IF @b_debug=1
               BEGIN
                  PRINT '@c_ParcelType:' + @c_ParcelType + ', @c_TaskType=' + @c_TaskType
                  PRINT '>>> ' + @c_OrderKey
               END

               SET @c_BoxType   = ''
               SET @c_ParcelSize= ''
               SET @b_NonParcel = 0
               SET @c_GroupKey  = ''
               SET @c_Lot = ''                                                      --USH022-01
               SET @c_LinkTaskToPick_SQL = 'PICKDETAIL.OrderKey = @c_OrderKey
                              AND PICKDETAIL.UOM = @c_UOM AND PICKDETAIL.Loc = @c_Fromloc
                              AND PICKDETAIL.ID = @c_FromID'
               SET @b_InsertTask = 1                                                --USH022-01

               SELECT TOP 1
                       @b_NonParcel = IIF(cl.UDF01= 'Non-Parcel',1,0)
                     , @c_BoxType   = IIF(cl.UDF01= 'Parcel',cl.UDF02,'')
                     , @c_ParcelSize= IIF(cl.UDF01= 'Parcel',cl.Code2,'')
               FROM #TMP_CODELKUP cl
               WHERE cl.ListName = 'HUSQPKTYPE'
               AND cl.Storerkey = @c_Storerkey
               AND cl.Short = @c_ParcelType

               SET @c_TaskType  = 'ASTCPK'
               SET @c_PickMethod= 'PP'

               SET @c_ToLoc = @c_OtherReference
               IF @b_NonParcel = 1 AND @b_VASFlag = 1
               BEGIN
                  SET @c_ToLoc = 'DNVAS01'
               END

               IF @c_BoxType <> ''
                  SET @c_Message01 = @c_BoxType
               ELSE
                  SET @c_Message01 = @c_PalletType

               IF @b_NonParcel = 1
                  SET @c_Message02 = @n_MaxHeight

               IF @b_NonParcel = 1
                  SET @c_Message03 = @n_NoOfPallet

               SELECT @n_Qty = SUM(QTY) FROM #PickDetail_WIP PDW (NOLOCK)  --USH022-01
               WHERE PDW.WaveKey = @c_WaveKey
               AND PDW.Sku = @c_Sku
               AND PDW.ID = @c_ID
               AND PDW.Loc = @c_Loc
               AND PDW.Orderkey = @c_Orderkey
               AND PDW.[Status] < '5'
               GROUP BY PDW.Sku, PDW.ID, PDW.Loc;                          --USH022-01

               IF @b_debug=1
               BEGIN
                  PRINT '@b_NonParcel:' + CAST(@b_NonParcel as varchar(10))
                  SELECT @c_GroupKey '@c_GroupKey', @n_NoOfPallet '@n_NoOfPallet', @c_Sku '@c_Sku' ,@c_Sku_Last '@c_Sku_Last', @c_SkuClass '@c_SkuClass'
               END

            END
         END

         IF @n_Continue = 1
         BEGIN
            SET @c_ToLogicalLoc = ''
            SELECT @c_ToLogicalLoc = l.LogicalLocation
            FROM LOC l (NOLOCK)
            WHERE l.Loc = @c_ToLoc

            --Insert Taskdetail
            IF @b_NonParcel = 0
            SET @c_TaskStatus = '0'

            IF @b_InsertTask = 1                                  --USH022-01
            BEGIN
                SET @c_TaskDetailKey = ''

                EXEC isp_InsertTaskDetail
                @c_TaskDetailKey         = @c_TaskDetailKey OUTPUT
                ,  @c_TaskType              = @c_TaskType
                ,  @c_Storerkey             = @c_Storerkey
                ,  @c_Sku                   = @c_Sku
                ,  @c_Lot                   = @c_Lot
                ,  @c_UOM                   = @c_UOM
                ,  @n_UOMQty                = @n_UOMQty
                ,  @n_Qty                   = @n_Qty
                ,  @c_FromLoc               = @c_Fromloc
                ,  @c_LogicalFromLoc        = @c_FromLogicalLoc
                ,  @c_FromID                = @c_ID
                ,  @c_ToLoc                 = @c_ToLoc
                ,  @c_LogicalToLoc          = @c_ToLogicalLoc
                ,  @c_ToID                  = @c_ID
                ,  @c_PickMethod            = @c_PickMethod
                ,  @c_Priority              = @c_Priority
                ,  @c_SourcePriority        = '9'
                ,  @c_SourceType            = @c_SourceType
                ,  @c_SourceKey             = @c_Wavekey
                ,  @c_PickDetailkey         = @c_PickDetailkey
                ,  @c_OrderKey              = @c_OrderKey
                ,  @c_Groupkey              = @c_Groupkey
                ,  @c_WaveKey               = @c_Wavekey
                ,  @c_AreaKey               = '?F'  -- ?F=Get from location areakey
                ,  @c_Message01             = @c_Message01
                ,  @c_Message02             = @c_Message02
                ,  @c_Message03             = @c_Message03
                ,  @c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip
                ,  @c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL
                ,  @c_SplitTaskByCase       ='N'   -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.
                ,  @c_WIP_RefNo             = @c_SourceType
                ,  @b_Success               = @b_Success     OUTPUT
                ,  @n_Err                   = @n_err         OUTPUT
                ,  @c_ErrMsg                = @c_errmsg      OUTPUT
                ,  @c_Status                = @c_TaskStatus
                ,  @c_Loadkey               = @c_Loadkey  -- 16/11 WS: added to allows me testig RDT FCR's but Please validate this

            END
         END

         IF @n_Continue = 1
         BEGIN
            UPDATE PICKDETAIL WITH (ROWLOCK)
               SET PickSlipNo = CASE WHEN ISNULL(PickSlipNo,'') = '' THEN @c_PickSlipNo ELSE PickSlipNo END
                  , EditDate = GETDATE()
                  , TrafficCop = NULL
                  , TaskDetailKey = @c_TaskDetailKey
                  , Notes = CASE WHEN ISNULL(Notes,'') = '' THEN LOC ELSE Notes END
            WHERE PickDetailKey = @c_PickDetailkey

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
            END
         END

         IF @n_Continue = 1
         BEGIN
            IF EXISTS (SELECT 1 FROM RefKeyLookup (NOLOCK) WHERE PickDetailkey = @c_PickDetailkey)
            BEGIN
               UPDATE RefKeyLookup WITH (ROWLOCK)
                     SET Pickslipno = @c_PickSlipNo
                        ,OrderKey = @c_OrderKey
                        ,OrderLineNumber = @c_OrderLineNumber
                        ,Loadkey = @c_Loadkey
                        ,ArchiveCop = NULL
               WHERE PickDetailkey = @c_PickDetailkey
            END
            ELSE
            BEGIN
               INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)
               VALUES (@c_PickDetailkey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber, @c_Loadkey)
            END

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
            END
         END

         SET @c_OrderKey_Last = @c_OrderKey
         SET @c_ParcelType_Last = @c_ParcelType
         SET @c_Sku_Last      = @c_Sku
         SET @c_SkuClass_Last = @c_SkuClass
         SET @c_GroupKey_Last = @c_GroupKey
         SET @c_TaskType_Last = @c_TaskType
         SET @c_ParcelSize_Last = @c_ParcelSize
         SET @c_Loc_Last        = @c_Loc                    --USH022-01
         SET @c_ID_Last         = @c_ID                     --USH022-01
         FETCH NEXT FROM @CUR_PCK INTO @c_PickdetailKey
                                    ,  @c_OrderKey
                                    ,  @c_OrderLineNumber
                                    ,  @c_Storerkey
                                    ,  @c_Sku
                                    ,  @c_Lot
                                    ,  @c_FromLoc
                                    ,  @c_ID
                                    ,  @c_UOM
                                    ,  @n_Qty
                                    ,  @c_SkuClass
                                    ,  @c_SerialNoCapture
                                    ,  @n_StdGrossWgt
                                    ,  @n_PackCube
                                    ,  @c_FromLogicalLoc
                                    ,  @c_LocAisle
                                    ,  @c_Loadkey
                                    ,  @c_Consigneekey
                                    ,  @c_C_Zip
                                    ,  @c_ParcelType
      END
      CLOSE @CUR_PCK
      DEALLOCATE @CUR_PCK
   END

   IF @b_debug=1
   BEGIN
       SELECT TD.Storerkey
       , TD.TaskDetailKey
       , LOC.LogicalLocation
       , OH.OrderKey
       , S.Sku
       , S.Class
       , TD.Qty * (P.WidthUOM3 * P.LengthUOM3 * P.HeightUOM3) AS TaskCube
       , TD.Qty * S.StdGrossWgt AS [TaskWeight]
       , CL.UDF01
       , GroupKey
       , TD.TaskType
       , CL.Code2
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
      JOIN SKU S (NOLOCK) ON  S.Storerkey = TD.Storerkey AND S.Sku = TD.Sku
      JOIN dbo.ORDERS OH WITH (NOLOCK) ON OH.OrderKey = TD.OrderKey
      JOIN PACK P  (NOLOCK) ON  P.Packkey = S.Packkey
      JOIN dbo.CODELKUP cl ON  cl.listName = 'HUSQPKTYPE'
                           AND cl.StorerKey = OH.Storerkey
                           AND cl.Short = OH.Userdefine10
      WHERE  TD.TaskType = 'ASTCPK'
      AND TD.WaveKey = @c_Wavekey
   END
   /*****************************************************/
   /* Assign Group Key for task type ASTCPK- non-parcel */
   /*****************************************************/
   IF @n_Continue=1
   BEGIN
      IF OBJECT_ID('tempdb..#tmpNonParcel','u') IS NOT NULL
      BEGIN
         DROP TABLE #tmpNonParcel;
      END

      CREATE TABLE #tmpNonParcel (
      RowID INT IDENTITY(1, 1) PRIMARY KEY,
      StorerKey         NVARCHAR(15),
      TaskDetailKey     NVARCHAR(10),
      LogicalLocation   NVARCHAR(10),
      OrderKey          NVARCHAR(10),
      SKU               NVARCHAR(10),
      SKUClass          NVARCHAR(20),
      TaskCube          FLOAT,
      TaskWeight        FLOAT,
      GroupKey          NVARCHAR(10)
      )

      SELECT TOP 1 @c_Storerkey = Storerkey
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE WaveKey = @c_WaveKey

      SELECT @n_MaxCube_df      = IIF(ISNUMERIC(ST.SUSR1)=1,CONVERT(FLOAT,ST.SUSR1),0.00)
            ,@n_MaxHeight_df    = IIF(ISNUMERIC(ST.SUSR2)=1,CONVERT(FLOAT,ST.SUSR2),0.00)
            ,@n_MaxWeight_df    = IIF(ISNUMERIC(ST.SUSR3)=1,CONVERT(FLOAT,ST.SUSR3),0.00)
            ,@c_OneBrand_df     = ST.SUSR4
            ,@n_NoOfPallet_df   = IIF(ISNULL(ST.CreditLimit,'0') IN ('0',''),2,1)
            ,@c_PalletType_df   = ISNULL(ST.Pallet,'')
      FROM STORER ST (NOLOCK)
      WHERE ST.[Type] = '2'
      AND   ST.ConsigneeFor = @c_Storerkey
      AND   ST.Storerkey = '0000000001'

      INSERT INTO #tmpNonParcel (
            StorerKey
         ,   TaskDetailKey
         ,   LogicalLocation
         ,   OrderKey
         ,   SKU
         ,   SKUClass
         ,   TaskCube
         ,   TaskWeight
         ,   GroupKey
      )
       SELECT TD.Storerkey
       , TD.TaskDetailKey
       , LOC.LogicalLocation
       , OH.OrderKey
       , S.Sku
       , S.Class
       , TD.Qty * (P.WidthUOM3 * P.LengthUOM3 * P.HeightUOM3) AS TaskCube
       , TD.Qty * S.StdGrossWgt AS [TaskWeight]
       , '' AS GroupKey
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
      JOIN SKU S (NOLOCK) ON  S.Storerkey = TD.Storerkey AND S.Sku = TD.Sku
      JOIN dbo.ORDERS OH WITH (NOLOCK) ON OH.OrderKey = TD.OrderKey
      JOIN PACK P  (NOLOCK) ON  P.Packkey = S.Packkey
      JOIN dbo.CODELKUP cl ON  cl.listName = 'HUSQPKTYPE'
                           AND cl.StorerKey = OH.Storerkey
                           AND cl.Short = OH.Userdefine10
      WHERE  TD.TaskType = 'ASTCPK'
      AND CL.UDF01 = 'Non-Parcel'
      AND TD.WaveKey = @c_WaveKey
      ORDER BY LOC.LogicalLocation

      SET @n_Tolerance = 100.00
      SELECT @n_Tolerance = IIF(ISNUMERIC(cl.UDF05)=1,CONVERT(FLOAT,cl.UDF05),100.00)
      FROM CODELKUP cl(NOLOCK)
      WHERE cl.LISTNAME ='HUSQ_MHE'
      AND cl.Storerkey = @c_Storerkey
      AND cl.Code ='PALL_MHE'

      DECLARE CUR_NonParcelTask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT OrderKey
      FROM #tmpNonParcel
      ORDER BY OrderKey

      OPEN CUR_NonParcelTask

      FETCH NEXT FROM CUR_NonParcelTask INTO @c_OrderKey

      WHILE @@FETCH_STATUS = 0
      BEGIN
         SELECT @n_MaxCube   = IIF(ISNUMERIC(ST.SUSR1)=1,CONVERT(FLOAT,ST.SUSR1),@n_MaxCube_df)
               ,@n_MaxHeight = IIF(ISNUMERIC(ST.SUSR2)=1,CONVERT(FLOAT,ST.SUSR2),@n_MaxHeight_df)
               ,@n_MaxWeight = IIF(ISNUMERIC(ST.SUSR3)=1,CONVERT(FLOAT,ST.SUSR3),@n_MaxWeight_df)
               ,@c_OneBrand  = IIF(ST.SUSR4 IS NULL,@c_OneBrand_df,ST.SUSR4)
               ,@n_Capacity  = CASE WHEN ISNULL(ST.CreditLimit, 0) = 0 THEN 2 ELSE 1 END
               ,@n_MaxSKU    = CASE WHEN ISNULL(ST.CreditLimit, 0) > 0 THEN CAST(ST.CreditLimit AS INT) ELSE 0 END
               ,@c_PalletType= IIF(ST.Pallet IN ('',NULL),@c_PalletType_df,ST.Pallet)
         FROM ORDERS OH (NOLOCK)
         LEFT OUTER JOIN STORER ST (NOLOCK) ON  ST.Address1 = OH.ConsigneeKey
                                 AND ST.Zip      = OH.C_Zip
                                 AND ST.ConsigneeFor = OH.Storerkey
                                 AND ST.[Type] = '2'
         WHERE OH.OrderKey = @c_OrderKey

         SET @n_TotalCube = 0
         SET @n_TotalWeight = 0
         SET @c_GroupKey = ''

         IF @b_debug=1
         BEGIN
            PRINT '@n_Capacity:' + cast(@n_Capacity as varchar(10)) + ',  @n_Tolerance:' + cast(@n_Tolerance as varchar(10))
            PRINT '1 - @n_MaxWeight:' + cast(CAST(@n_MaxWeight as Decimal(10,3)) as varchar(20)) + ',  @n_MaxCube:' + cast(CAST(@n_MaxCube AS Decimal(10,3)) as varchar(20))
         END

         SET @n_MaxCube   = @n_MaxCube   * (@n_Tolerance / 100.00)
         SET @n_MaxWeight = @n_MaxWeight * (@n_Tolerance / 100.00)

         IF @n_Capacity=2
         BEGIN
            SET @n_MaxCube   = @n_MaxCube * 2
            SET @n_MaxWeight = @n_MaxWeight * 2
         END

         IF @b_debug=1
            PRINT '2 - @n_MaxWeight:' + cast(@n_MaxWeight as varchar(10)) + '@n_MaxCube:' + cast(CAST(@n_MaxCube AS Decimal(10,1)) as varchar(20))

          DECLARE CUR_OrderTask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT RowID, TaskDetailKey, TaskCube, TaskWeight, SKU, SKUClass
          FROM #tmpNonParcel
          WHERE OrderKey=@c_OrderKey
          ORDER BY RowID


          OPEN CUR_OrderTask

          FETCH NEXT FROM CUR_OrderTask INTO @n_RowID, @c_TaskDetailKey, @n_Cube, @n_Weight, @c_Sku, @c_SkuClass

          WHILE @@FETCH_STATUS = 0
          BEGIN
              SET @n_TotalWeight = @n_TotalWeight + @n_Weight
              SET @n_TotalCube = @n_TotalCube + @n_Cube

               IF @b_debug=1
                  PRINT '3 - Total Weight:' + cast(@n_TotalWeight as varchar(10)) + '@n_TotalCube:' + cast(CAST(@n_TotalCube AS Decimal(10,1)) as varchar(20))

              IF @c_GroupKey <> ''
              BEGIN
                 IF @n_TotalWeight > @n_MaxWeight OR @n_TotalCube > @n_MaxCube
                 BEGIN
                    Print '@n_TotalCube > @n_MaxCube'
                    SET @c_GroupKey = ''
                    SET @n_TotalWeight = @n_Weight
                    SET @n_TotalCube = @n_Cube
                    GOTO Gen_GroupKey
                 END

                 IF @n_Capacity=1
                 BEGIN
                     SET @n_TotalSKU = 0
                     SELECT @n_TotalSKU = COUNT(DISTINCT SKU)
                     FROM #tmpNonParcel
                     WHERE GroupKey = @c_GroupKey
                     AND SKU <> @c_SKU

                     IF @n_TotalSKU + 1 > @n_MaxSKU
                     BEGIN
                        SET @c_GroupKey = ''
                        GOTO Gen_GroupKey
                     END
                 END

                 IF @c_OneBrand = 'N'
                 BEGIN
                    IF NOT EXISTS(SELECT 1 FROM #tmpNonParcel WHERE GroupKey = @c_GroupKey AND SKUClass = @c_SkuClass)
                    BEGIN
                        SET @c_GroupKey = ''
                        GOTO Gen_GroupKey
                    END
                 END
              END

              Gen_GroupKey:
              IF @c_GroupKey = ''
              BEGIN
                  SET @b_success = 1
                  EXECUTE nspg_getkey
                           @KeyName   = 'GroupKey'
                        , @fieldlength = 10
                        , @KeyString   = @c_GroupKey     OUTPUT
                        , @b_success   = @b_success      OUTPUT
                        , @n_err       = @n_err          OUTPUT
                        , @c_errmsg    = @c_errmsg       OUTPUT

                  IF @b_success = 0
                  BEGIN
                     SET @n_Continue = 3
                  END
              END

              UPDATE #tmpNonParcel
                SET GroupKey = @c_GroupKey
              WHERE RowID = @n_RowID

              UPDATE dbo.TaskDetail
                SET Groupkey=@c_GroupKey,
                    EditDate=GETDATE()
              WHERE TaskDetailKey = @c_TaskDetailKey

              FETCH NEXT FROM CUR_OrderTask INTO @n_RowID, @c_TaskDetailKey, @n_Cube, @n_Weight, @c_Sku, @c_SkuClass
          END

          CLOSE CUR_OrderTask
          DEALLOCATE CUR_OrderTask

          FETCH NEXT FROM CUR_NonParcelTask INTO @c_OrderKey
      END

      CLOSE CUR_NonParcelTask
      DEALLOCATE CUR_NonParcelTask
   END -- IF continue - 1


   /*****************************************************/
   /* Assign Group Key for task type ASTCPK- Parcel     */
   /*****************************************************/
   IF @n_Continue=1
   BEGIN
      IF OBJECT_ID('tempdb..#tmpParcel','u') IS NOT NULL
      BEGIN
         DROP TABLE #tmpParcel;
      END

      CREATE TABLE #tmpParcel (
      RowID INT IDENTITY(1, 1) PRIMARY KEY,
      StorerKey         NVARCHAR(15),
      ParcelSize        NVARCHAR(30),
      TaskDetailKey     NVARCHAR(10),
      LogicalLocation   NVARCHAR(10),
      OrderKey          NVARCHAR(10),
      SKU               NVARCHAR(10),
      SKUClass          NVARCHAR(20),
      TaskCube          FLOAT,
      TaskWeight        FLOAT,
      GroupKey          NVARCHAR(10)
      )

      SELECT TOP 1
            @c_Storerkey = TD.Storerkey,
            @c_Facility = LOC.Facility
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON TD.FromLoc = LOC.LOC
      WHERE WaveKey = @c_WaveKey

      SELECT @n_MaxCube_df      = IIF(ISNUMERIC(ST.SUSR1)=1,CONVERT(FLOAT,ST.SUSR1),0.00)
            ,@n_MaxHeight_df    = IIF(ISNUMERIC(ST.SUSR2)=1,CONVERT(FLOAT,ST.SUSR2),0.00)
            ,@n_MaxWeight_df    = IIF(ISNUMERIC(ST.SUSR3)=1,CONVERT(FLOAT,ST.SUSR3),0.00)
            ,@c_OneBrand_df     = ST.SUSR4
            ,@n_NoOfPallet_df   = IIF(ISNULL(ST.CreditLimit,'0') IN ('0',''),2,1)
            ,@c_PalletType_df   = ISNULL(ST.Pallet,'')
      FROM STORER ST (NOLOCK)
      WHERE ST.[Type] = '2'
      AND   ST.ConsigneeFor = @c_Storerkey
      AND   ST.Storerkey = '0000000001'

      SET @n_Tolerance_T = 100.00
      SELECT @n_Tolerance_T = IIF(ISNUMERIC(cl.long)=1,CONVERT(FLOAT,cl.long),100.00)
      FROM CODELKUP cl (NOLOCK)
      WHERE cl.LISTNAME ='TRLCAPHUSQ'
      AND cl.Storerkey = @c_Storerkey
      AND cl.Code ='OUT'
      AND cl.Short= '1'

      SET @n_TrolleyCube = 0.00
      SELECT TOP 1 @n_TrolleyCube = l.[Cube]
      FROM LOC l(NOLOCK)
      WHERE l.Facility = @c_Facility
      AND l.LocationType = 'TROLLEYOB'
      ORDER BY l.Loc

      SET @n_TrolleyCube = @n_TrolleyCube * (@n_Tolerance_T / 100.00)

      INSERT INTO #tmpParcel (
         StorerKey
       , ParcelSize
       , TaskDetailKey
       , LogicalLocation
       , OrderKey
       , SKU
       , SKUClass
       , TaskCube
       , TaskWeight
       , GroupKey
      )
       SELECT TD.Storerkey
       , CL.code2
       , TD.TaskDetailKey
       , LOC.LogicalLocation
       , OH.OrderKey
       , S.Sku
       , S.Class
       , TD.Qty * (P.WidthUOM3 * P.LengthUOM3 * P.HeightUOM3) AS TaskCube
       , TD.Qty * S.StdGrossWgt AS [TaskWeight]
       , '' AS GroupKey
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
      JOIN SKU S (NOLOCK) ON  S.Storerkey = TD.Storerkey AND S.Sku = TD.Sku
      JOIN dbo.ORDERS OH WITH (NOLOCK) ON OH.OrderKey = TD.OrderKey
      JOIN PACK P  (NOLOCK) ON  P.Packkey = S.Packkey
      JOIN dbo.CODELKUP cl ON  cl.listName = 'HUSQPKTYPE'
                           AND cl.StorerKey = OH.Storerkey
                           AND cl.Short = OH.Userdefine10
      WHERE  TD.TaskType = 'ASTCPK'
      AND CL.UDF01 = 'Parcel'
      AND TD.WaveKey = @c_WaveKey
      ORDER BY LOC.LogicalLocation

      SET @n_Tolerance = 100.00
      SELECT @n_Tolerance = IIF(ISNUMERIC(cl.UDF05)=1,CONVERT(FLOAT,cl.UDF05),100.00)
      FROM CODELKUP cl(NOLOCK)
      WHERE cl.LISTNAME ='HUSQ_MHE'
      AND cl.Storerkey = @c_Storerkey
      AND cl.Code ='PALL_MHE'

      DECLARE CUR_NonParcelTask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT ParcelSize
      FROM #tmpParcel
      ORDER BY ParcelSize

      OPEN CUR_NonParcelTask

      FETCH NEXT FROM CUR_NonParcelTask INTO @c_ParcelSize

      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @b_debug = 1
         BEGIN
            PRINT '@c_ParcelSize: ' + @c_ParcelSize
         END

         SET @n_TotalCube = 0
         SET @n_TotalWeight = 0
         SET @c_GroupKey = ''

         IF @c_ParcelSize = 'UnderSized'
         BEGIN
            SET @n_MaxCube = @n_TrolleyCube
            SET @n_MaxWeight  = 0.00
         END

          DECLARE CUR_OrderTask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT RowID, TaskDetailKey, TaskCube, TaskWeight, SKU, SKUClass, OrderKey
          FROM #tmpParcel
          WHERE ParcelSize = @c_ParcelSize
          ORDER BY OrderKey, RowID


          OPEN CUR_OrderTask

          FETCH NEXT FROM CUR_OrderTask INTO @n_RowID, @c_TaskDetailKey, @n_Cube, @n_Weight, @c_Sku, @c_SkuClass, @c_OrderKey

          WHILE @@FETCH_STATUS = 0
          BEGIN
             IF @c_ParcelSize = 'UnderSized'
             BEGIN
                SET @n_Weight  = 0.00
             END

            SELECT @c_OneBrand  = IIF(ST.SUSR4 IS NULL,@c_OneBrand_df,ST.SUSR4)
            FROM ORDERS OH (NOLOCK)
            LEFT OUTER JOIN STORER ST (NOLOCK) ON  ST.Address1 = OH.ConsigneeKey
                                    AND ST.Zip      = OH.C_Zip
                                    AND ST.ConsigneeFor = OH.Storerkey
                                    AND ST.[Type] = '2'
            WHERE OH.OrderKey = @c_OrderKey

              SET @n_TotalWeight = @n_TotalWeight + @n_Weight
              SET @n_TotalCube = @n_TotalCube + @n_Cube

               IF @b_debug = 1
               BEGIN
                  PRINT '@n_TotalCube: ' + CAST(@n_TotalCube as VARCHAR(20)) +  ', @n_MaxCube:' + CAST(@n_MaxCube as VARCHAR(20))
               END

              IF @c_GroupKey <> ''
              BEGIN
                 IF @c_ParcelSize = 'UnderSized' AND (@n_TotalWeight > @n_MaxWeight OR @n_TotalCube > @n_MaxCube)
                 BEGIN
                    SET @c_GroupKey = ''
                    SET @n_TotalWeight = @n_Weight
                    SET @n_TotalCube = @n_Cube
                    GOTO Gen_ParcelGroupKey
                 END
                 IF @c_ParcelSize = 'OverSized'
                 BEGIN
                     SET @n_OrderCnt = 0
                     SELECT @n_OrderCnt = COUNT(DISTINCT OrderKey)
                     FROM #tmpParcel
                     WHERE GroupKey = @c_GroupKey
                     AND ParcelSize = @c_ParcelSize
                     AND OrderKey <> @c_OrderKey

                     SET @n_OrderCnt = @n_OrderCnt + 1
                     IF @n_OrderCnt > @n_MaxOrderPerGroup
                     BEGIN
                        SET @c_GroupKey = ''
                        GOTO Gen_ParcelGroupKey
                     END
                 END
                 IF @c_OneBrand = 'N'
                 BEGIN
                    IF NOT EXISTS(SELECT 1 FROM #tmpParcel WHERE GroupKey = @c_GroupKey AND SKUClass = @c_SkuClass)
                    BEGIN
                        SET @c_GroupKey = ''
                        GOTO Gen_ParcelGroupKey
                    END
                 END
              END

              Gen_ParcelGroupKey:
              IF @c_GroupKey = ''
              BEGIN
                  SET @b_success = 1
                  EXECUTE nspg_getkey
                           @KeyName   = 'GroupKey'
                        , @fieldlength = 10
                        , @KeyString   = @c_GroupKey     OUTPUT
                        , @b_success   = @b_success      OUTPUT
                        , @n_err       = @n_err          OUTPUT
                        , @c_errmsg    = @c_errmsg       OUTPUT

                  IF @b_success = 0
                  BEGIN
                     SET @n_Continue = 3
                  END
              END

              UPDATE #tmpParcel
                SET GroupKey = @c_GroupKey
              WHERE RowID = @n_RowID

              UPDATE dbo.TaskDetail
                SET Groupkey=@c_GroupKey,
                    Message02 = '',
                    Message03 = '',
                    EditDate=GETDATE()
              WHERE TaskDetailKey = @c_TaskDetailKey

              FETCH NEXT FROM CUR_OrderTask INTO @n_RowID, @c_TaskDetailKey, @n_Cube, @n_Weight, @c_Sku, @c_SkuClass, @c_OrderKey
          END

          CLOSE CUR_OrderTask
          DEALLOCATE CUR_OrderTask

          FETCH NEXT FROM CUR_NonParcelTask INTO @c_ParcelSize
      END

      CLOSE CUR_NonParcelTask
      DEALLOCATE CUR_NonParcelTask
   END -- IF continue - 1

   /**************************************/
   /* Additional sorting order for task  */
   /**************************************/
   /* declare variables */
   DECLARE @c_OrderGroup      NVARCHAR(20)=''
          ,@c_FirstOrderGroup NVARCHAR(20)=''

   DECLARE CUR_OrderGroup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT CASE WHEN ISNULL(O.OrderGroup,'') = '' THEN '999999' ELSE O.OrderGroup END AS OrderGroup, O.OrderKey
   FROM dbo.ORDERS O WITH (NOLOCK)
   JOIN dbo.WAVEDETAIL WD WITH (NOLOCK) ON WD.OrderKey = O.OrderKey
   WHERE WD.WaveKey = @c_WaveKey
   ORDER BY CASE WHEN ISNULL(O.OrderGroup,'') = '' THEN '999999' ELSE O.OrderGroup END

   OPEN CUR_OrderGroup

   FETCH NEXT FROM CUR_OrderGroup INTO @c_OrderGroup, @c_OrderKey

   WHILE @@FETCH_STATUS = 0
   BEGIN
       IF @c_FirstOrderGroup=''
          SET @c_FirstOrderGroup = @c_OrderGroup

       IF @c_FirstOrderGroup = '999999'
       BEGIN
          -- system should generate task as per current process as all Orders.OrderGroup = ''
          BREAK
       END

       ELSE
       BEGIN
          IF @c_FirstOrderGroup =  @c_OrderGroup
            SET @c_TaskStatus='0'
          ELSE
            SET @c_TaskStatus = 'S'

          DECLARE CUR_TASKDETAIL_REC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT TD.TaskDetailKey
          FROM dbo.TaskDetail TD WITH (NOLOCK)
          WHERE TD.WaveKey = @c_WaveKey
          AND TD.OrderKey = @c_OrderKey
          AND TD.Status IN ('0','S')


          OPEN CUR_TASKDETAIL_REC

          FETCH NEXT FROM CUR_TASKDETAIL_REC INTO @c_TaskDetailKey

          WHILE @@FETCH_STATUS = 0
          BEGIN
              UPDATE dbo.TaskDetail WITH (ROWLOCK)
               SET Status=@c_TaskStatus, TrafficCop=NULL
              WHERE TaskDetailKey=@c_TaskDetailKey

              FETCH NEXT FROM CUR_TASKDETAIL_REC INTO @c_TaskDetailKey
          END

          CLOSE CUR_TASKDETAIL_REC
          DEALLOCATE CUR_TASKDETAIL_REC
       END

       FETCH NEXT FROM CUR_OrderGroup INTO @c_OrderGroup, @c_OrderKey
   END

   CLOSE CUR_OrderGroup
   DEALLOCATE CUR_OrderGroup

RETURN_SP:
 -----Delete pickdetail_WIP work in progress staging table
   IF @n_continue IN (1,2)
   BEGIN
      EXEC isp_CreatePickdetail_WIP
            @c_Loadkey               = ''
         ,  @c_Wavekey               = @c_wavekey
         ,  @c_WIP_RefNo             = @c_SourceType
         ,  @c_PickCondition_SQL     = ''
         ,  @c_Action                = 'D'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
         ,  @c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
         ,  @b_Success               = @b_Success OUTPUT
         ,  @n_Err                   = @n_Err     OUTPUT
         ,  @c_ErrMsg                = @c_ErrMsg  OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END
   END

   IF OBJECT_ID('tempdb..#PICKDETAIL_WIP') IS NOT NULL
      DROP TABLE #PICKDETAIL_WIP

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'mspRLWAV04'
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