SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/****************************************************************************************************/
/* Store Procedure:  isp_BackendCancelOrders                                                        */
/* Creation Date: 12-May-2015                                                                       */
/* Copyright: LFL                                                                                   */
/* Written by:                                                                                      */
/*                                                                                                  */
/* Purpose: Presale Cancellation                                                                    */
/*                                                                                                  */
/* Input Parameters:  @c_DataStream    - Data Stream Code                                           */
/*                    @b_debug         - 0                                                          */
/*                                                                                                  */
/* Output Parameters: @b_Success       - Success Flag  = 0                                          */
/*                    @n_Err           - Error Code    = 0                                          */
/*                    @c_ErrMsg        - Error Message = ''                                         */
/*                                                                                                  */
/* Called By:                                                                                       */
/*                                                                                                  */
/* PVCS Version: 1.0                                                                                */
/*                                                                                                  */
/* Version: 1.0                                                                                     */
/*                                                                                                  */
/* Data Modifications:                                                                              */
/*                                                                                                  */
/* Updates:                                                                                         */
/* Date        Author         Ver.  Purposes                                                        */
/*  2019-02-11  TLTING        1.0   Copy from isp0000P_WSIML_GENERIC_WMS_CancOrd_Import             */
/*  2019-09-27  kocy          1.1   add a checking part of Update o.EditDate at @c_OH_Status > '0'  */
/*  2019-10-23  kocy02        1.2   add CongfigKey for HM (BackendCancelOrders)                     */
/*                                  https://jiralfl.atlassian.net/browse/WMS-10895                  */
/*  2019-12-18  kocy03        1.3   skip to NEXT_PICKDETAIL_RECORD when OverAllocationFlag = '1'    */
/*                                  and lotxlotxid.QtyExpected > 0                                  */
/*                                  https://jiralfl.atlassian.net/browse/WMS-11462                  */
/*                                                                                                  */
/* 2020-01-16   kocy04        1.4   Added delete WaveDetail records based on OrderKey               */
/* 2020-02-17   kocy05        1.5   Comment out Delete WaveDetail record first                      */
/* 2020-04-14   NJOW01        1.6   WMS-12785 Lululemon move stock logic                            */
/* 2020-07-29   NJOW02        1.7   Fix temploc bug follow isp0000P_WSIML_GENERIC_WMS_CancOrd_Import*/
/* 2020-09-14   NJOW03        1.8   WMS-14932 Move to TempLoc Logic Update                          */
/* 2021-11-08   NJOW04        1.9   WMS-18345 PVH config to move pre-sales order to different loc   */
/* 2021-11-08   NJOW04        1.9   DEVOPS combine script                                           */
/* 2022-04-25   TLTING01      1.10  WMS-19304 S41 CancelOrder cahnge lotattribute 07 & 11           */
/* 2022-04-25   TLTING02      1.11  WMS-19304 Add TempLoc Logic - refer to LFI-3243                 */
/* 2022-11-07   NJOW05        1.12  WMS-21140 CN PVH New param to skip update order to cancel status*/
/* 2023-04-25   NJOW06        1.13  WMS-22421 CN Dyson include delete packserialno                  */
/****************************************************************************************************/

CREATE     PROC [dbo].[isp_BackendCancelOrders] (
       @c_Orderkey         NVARCHAR(10)
     , @b_debug            INT            = 0
     , @b_Success          INT            = 0   OUTPUT
     , @n_Err              INT            = 0   OUTPUT
     , @c_ErrMsg           NVARCHAR(215)  = ''  OUTPUT
     , @c_IgnorCancOrd     NVARCHAR(10)   = 'N'   --Y=Skip update sostatus from PENDCANC to CANC. 
                                                  --LIT can manually run the SP to unallocate and move cancel stock only without update sostatus
                                                  --After operation completed the physical move, resume the normal cancel process(@c_IgnorCancOrd=N) to update sotatus.
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   /*********************************************/
   /* Variables Declaration (Start)             */
   /*********************************************/
   --General
   DECLARE @n_Continue                 INT
         , @n_StartTCnt                INT
         , @n_RowCNT                   INT
         , @c_ExecStatements           NVARCHAR(4000)
         , @c_ExecArguments            NVARCHAR(4000)
         , @c_DefinedSOStatus          NVARCHAR(10)
         , @n_Exists                   INT
         , @c_OH_Status                NVARCHAR(10)
         , @c_OH_SOStatus              NVARCHAR(10)
         , @c_Doctype                  NChar(1)
         , @c_ShipperKey               NVARCHAR(15)
         , @c_Facility                 NVARCHAR(5)
         , @c_ExternOrderKey           NVARCHAR(50)
         , @c_OrderGroup               NVARCHAR(20)
         , @c_StorerKey                NVARCHAR(15)
         , @c_SC_SValue                NVARCHAR(10)
         , @n_WSOrdCancMoveToLoc_Task_Exist INT
         , @n_WSOrdCancMoveToLoc_Exist INT
         , @n_WSOrdCancMoveToLoc_PS_Exist    INT
         , @c_SC_SValue1               NVARCHAR(10)
         , @c_SC_SValue2               NVARCHAR(10)
         , @c_SC_SValue3               NVARCHAR(10)
         , @c_SC_WSFORCECANCORD_SValue NVARCHAR(30)
         , @c_SC_Option1               NVARCHAR(50)
         , @c_SC_Option2               NVARCHAR(50)
         --, @c_SC_WSSKIPCANC_SValue     NVARCHAR(30)
         --, @c_SC_WSSKIPCANC_OPTION1    NVARCHAR(100)
         , @c_OH_Doctype               NVARCHAR(1)
         , @c_OH_Priority              NVARCHAR(10)
         , @c_OH_ECOM_PRESALE_FLAG     NVARCHAR(2)
         , @n_AllowCancelCombineOrd    INT
         , @c_ConsoOrderKey            NVARCHAR(30)
         , @c_ConsoOrd_OrdSts          NVARCHAR(10)
         , @c_ConsoOrd_SOSts           NVARCHAR(10)
         , @dt_ConsoOrd_AddDate        DATETIME
         , @c_StatusPENDCANC           NVARCHAR(10)
         , @c_OD_OrderLineNumber       NVARCHAR(5)
         , @c_PD_SKU                   NVARCHAR(20)
         , @c_PD_Lot                   NVARCHAR(10)
         , @c_PD_Loc                   NVARCHAR(10)
         , @c_PD_ID                    NVARCHAR(18)
         , @n_PD_Qty                   INT
         , @c_From_Loc                 NVARCHAR(10)
         , @c_From_ID                  NVARCHAR(18)
         , @c_To_Loc                   NVARCHAR(10)
         , @c_To_ID                    NVARCHAR(18)

   --NJOW01
   DECLARE @c_WSOrdCancMoveToLoc_Opt1  NVARCHAR(50)
         , @c_LPUserDefine01           NVARCHAR(20)
         , @c_ToLoc                    NVARCHAR(10)
         , @n_PackSerialNoKey          BIGINT --NJOW06

   DECLARE @c_PickSlipNo               NVARCHAR(10)
         , @n_CartonNo                 INT
         , @c_LabelNo                  NVARCHAR(20)
         , @c_LabelLine                NVARCHAR(5)
         , @c_PickDetailKey            NVARCHAR(18)
         , @c_PickHeaderKey            NVARCHAR(18)
         , @c_Temp_OrderLineNumber     NVARCHAR(5)
         , @c_Temp_Sku                 NVARCHAR(20)
         , @c_Temp_Lot                 NVARCHAR(10)
         , @c_Temp_FromLoc             NVARCHAR(10)
         , @c_Temp_FromID              NVARCHAR(18)
         , @c_Temp_ToLoc               NVARCHAR(10)
         , @c_Temp_ToID                NVARCHAR(18)
         , @n_Temp_Qty                 INT
         , @dt_Temp_Datetime           DATETIME
         , @c_PreAllocatePickDetailKey NVARCHAR(10)
         , @c_LoadKey                  NVARCHAR(25)
         , @c_LoadLineNumber           NVARCHAR(5)
         , @n_RowRef                   INT
         --, @c_Status                   Nvarchar(10)
         , @c_StatusCANC               Nvarchar(10)
         , @c_ChildOrderKey            Nvarchar(10)
         , @c_SL_LocationType          NVARCHAR(10)
         , @c_Loc_LocationType         NVARCHAR(10)
         , @c_SL_Loc                   NVARCHAR(10)
         , @c_Move2Loc_Long            NVARCHAR(250)
         , @c_Move2Loc_Short           NVARCHAR(10)
         , @c_Prev_ChildOrderKey       NVarchar(10)
         , @c_DB_ChildOrderKey         Nvarchar(10)
         , @c_DB_ChildOrderLineNumber  Nvarchar(5)
         , @n_BackendCancelOrders_Exist INT
         , @n_OverAllocationFlag_Exist  INT
         , @c_LLI_QtyExpected           INT
         , @c_WaveKey                   NVARCHAR(25)
         , @c_PD_PickDetailKey         NVARCHAR(18)   --NJOW02
         , @c_Temp_PickDetailKey       NVARCHAR(18)   --NJOW02
         , @c_WSOrdCancMoveToLoc_Opt2  NVARCHAR(50)   --NJOW03
         , @c_WSOrdCancMoveToLoc_Opt3  NVARCHAR(50)   --NJOW04
         , @c_ECOM_PRESALE_FLAG        NVARCHAR(2)    --NJOW04
         , @c_Move2Loc_UDF01           NVARCHAR(60)   --NJOW04

   --(TLTING02) -Start
   DECLARE @n_WSOrdCancMoveCustomized_Exist     INT
         , @c_CLK_WSMove2LocCustomized_Notes2   NVARCHAR(4000)
         , @c_CLK_WSMove2LocCustomized_Long     NVARCHAR(50)
   --(TLTING02) -End         

   --TLTING01 START  
   DECLARE @n_Channel_ID               INT  
         , @c_lottable01               NVARCHAR(18)  
         , @c_lottable02               NVARCHAR(18)  
         , @c_lottable03               NVARCHAR(18)  
         , @d_lottable04               DATETIME  
         , @d_lottable05               DATETIME  
         , @c_Lottable06               NVARCHAR(30)  
         , @c_Lottable07               NVARCHAR(30)  
         , @c_Lottable08               NVARCHAR(30)  
         , @c_Lottable09               NVARCHAR(30)  
         , @c_Lottable10               NVARCHAR(30)  
         , @c_Lottable11               NVARCHAR(30)  
         , @c_Lottable12               NVARCHAR(30)  
         , @d_Lottable13               DATETIME  
         , @d_Lottable14               DATETIME  
         , @d_Lottable15               DATETIME  
         , @n_S41_Exists               INT  
   --TLTING01 END  

   SET @n_StartTCnt = @@TRANCOUNT
   SET @b_Success = 0
   SET @n_RowCNT = 0
   SET @n_Err     = 0
   SET @c_ErrMsg  = ''
   SET @c_OH_Status = ''
   SET @c_OH_SOStatus = ''
   SET @c_DefinedSOStatus = ''
   SET @n_Exists = 0
   SET @c_StatusCANC = 'CANC'
   SET @c_ShipperKey = ''
   SET @c_Facility = ''
   SET @c_ExternOrderKey = ''
   SET @c_OrderGroup = ''
   SET @c_StorerKey = ''
   SET @c_SC_SValue = ''
   SET @n_WSOrdCancMoveToLoc_Exist  = 0
   SET @n_WSOrdCancMoveToLoc_Task_Exist = 0
   SET @n_WSOrdCancMoveToLoc_PS_Exist = 0
   SET @c_SC_SValue2 = ''
   SET @c_SC_WSFORCECANCORD_SValue = ''
   SET @c_SC_Option1                = ''
   SET @c_SC_Option2                = ''
   --SET @c_SC_WSSKIPCANC_SValue      = ''
   --SET @c_SC_WSSKIPCANC_OPTION1     = ''
   SET @c_Doctype                = ''
   --SET @c_Priority               = ''
   --SET @c_ECOM_PRESALE_FLAG      = ''
   SET @n_AllowCancelCombineOrd     = 0
   SET @c_StatusPENDCANC            = 'PENDCANC'
   SET @c_OD_OrderLineNumber     = ''
   SET @c_PD_SKU                 = ''
   SET @c_PD_Lot                 = ''
   SET @c_PD_Loc                 = ''
   SET @c_PD_ID                  = ''
   SET @n_PD_Qty                 = 0
   SET @c_PickSlipNo               = ''
   SET @n_CartonNo                 = ''
   SET @c_LabelNo                  = ''
   SET @c_LabelLine                = ''
   SET @c_PickDetailKey            = ''
   SET @c_PickHeaderKey            = ''
   SET @c_Temp_OrderLineNumber     = ''
   SET @c_Temp_Sku                 = ''
   SET @c_Temp_Lot                 = ''
   SET @c_Temp_FromLoc             = ''
   SET @c_Temp_FromID              = ''
   SET @c_Temp_ToLoc               = ''
   SET @c_Temp_ToID                = ''
   SET @n_Temp_Qty                 = 0
   SET @dt_Temp_Datetime           = NULL
   SET @c_PreAllocatePickDetailKey = ''
   SET @c_LoadKey                  = ''
   SET @c_LoadLineNumber           = ''
   SET @n_RowRef                   = 0
   SET @c_ChildOrderKey        = ''
   SET @c_SL_LocationType          = ''
   SET @c_Loc_LocationType         = ''
   SET @c_SL_Loc                   = ''
   SET @c_Move2Loc_Long            = ''
   SET @c_Move2Loc_Short           = ''
   SET @c_Prev_ChildOrderKey       = ''
   SET @c_DB_ChildOrderKey         = ''
   SET @c_DB_ChildOrderLineNumber  = ''
   SET @c_ConsoOrderKey            = ''
   SET @n_BackendCancelOrders_Exist = 0
   SET @n_OverAllocationFlag_Exist =  0
   SET @c_WSOrdCancMoveToLoc_Opt2  = '' --NJOW03
   SET @n_S41_Exists = 0

   --(TLTING02) -Start
   SET @n_WSOrdCancMoveCustomized_Exist = 0

   --(TLTING02) -End

   IF OBJECT_ID('tempdb..#TempMoveRecord') IS NOT NULL
   BEGIN
      DROP TABLE #TempMoveRecord
   END

   CREATE TABLE #TempMoveRecord
   (  rowref Int not null identity(1,1) Primary key,
      OrderLineNumber NVARCHAR(5) NOT NULL,
      SKU NVARCHAR(20) NULL,
      Lot NVARCHAR(10) NULL,
      FromLoc NVARCHAR(10) NULL,
      FromID NVARCHAR(18) NULL,
      ToLoc NVARCHAR(10) NULL,
      ToID NVARCHAR(18) NULL,
      Qty INT,
      PickDetailKey NVARCHAR(18) NOT NULL  --NJOW02
   )

   --CREATE UNIQUE INDEX IX_1 on #TempMoveRecord (OrderLineNumber, SKU, Lot, FromLoc)
   CREATE UNIQUE INDEX IX_Pdet on #TempMoveRecord (PickDetailKey)  --NJOW02

   SELECT  @n_Exists = (1)
         , @c_OH_Status = ISNULL(RTRIM(O.STATUS),'')
         , @c_OH_SOStatus = ISNULL(RTRIM(O.SOStatus),'')
         , @c_ShipperKey = ISNULL(RTRIM(O.ShipperKey),'')
         , @c_Facility = ISNULL(RTRIM(O.Facility),'')
         , @c_ExternOrderKey = ISNULL(RTRIM(O.ExternOrderKey), '')
         , @c_OrderGroup = ISNULL(RTRIM(O.OrderGroup), '')
         , @c_StorerKey = O.StorerKey
         , @c_Doctype    = ISNULL(RTRIM(O.Doctype),'')
         , @c_LPUserDefine01    = ISNULL(RTRIM(LP.UserDefine01),'') --NJOW01
        -- , @c_Priority   = ISNULL(RTRIM(Priority),'')
         , @c_ECOM_PRESALE_FLAG = ISNULL(RTRIM(ECOM_PRESALE_FLAG),'') --NJOW04
   FROM ORDERS o WITH (NOLOCK)
   LEFT JOIN LOADPLAN LP WITH (NOLOCK) ON O.Loadkey = LP.Loadkey --NJOW01
   WHERE O.OrderKey = @c_OrderKey
   SET @n_Err = @@ERROR
   IF @n_Err <> 0
   BEGIN
      ROLLBACK TRAN
      SET @n_Err = 80100
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                     + ': Select Orders Fail. '
                     + '. (isp_BackendCancelOrders)'
      GOTO PROCESS_END
   END

   IF @n_Exists = 0
      GOTO PROCESS_END

   SELECT @c_SC_SValue = SValue
   FROM  StorerConfig WITH (NOLOCK)
   WHERE StorerKey = @c_Storerkey
   AND ConfigKey = 'ByPassDeletePreAllocate'

   SELECT @n_WSOrdCancMoveToLoc_Exist = (1)
         ,@c_WSOrdCancMoveToLoc_Opt1 = Option1  -- NJOW01
         ,@c_WSOrdCancMoveToLoc_Opt3 = Option3  -- NJOW04
   FROM  StorerConfig WITH (NOLOCK)
   WHERE StorerKey = @c_Storerkey
   AND ConfigKey = 'WSOrdCancMoveToLoc'


   SELECT @n_WSOrdCancMoveToLoc_Task_Exist = (1)
   FROM  StorerConfig WITH (NOLOCK)
   WHERE StorerKey = @c_Storerkey
   AND ConfigKey = 'WSOrdCancMV2Loc_Task'
   AND SValue = '1'

   SELECT @n_WSOrdCancMoveToLoc_PS_Exist = (1)
   FROM  StorerConfig WITH (NOLOCK)
   WHERE StorerKey = @c_Storerkey
   AND ConfigKey = 'WSOrdCancMV2Loc_PickStatus'
   AND SValue = '1'

    SELECT @c_SC_SValue2 = SValue
    FROM  StorerConfig WITH (NOLOCK)
    WHERE StorerKey = @c_Storerkey
    AND ConfigKey = 'WSSkipRemoveTrackNo'

    SELECT @c_SC_WSFORCECANCORD_SValue = SValue
      , @c_SC_Option1 = ISNULL(RTRIM(OPTION1), '')
      , @c_SC_Option2 = ISNULL(RTRIM(OPTION2), '')
   FROM  StorerConfig WITH (NOLOCK)
   WHERE StorerKey = @c_Storerkey
   AND ConfigKey = 'WSFORCECANCORD'

    --SELECT @c_SC_WSSKIPCANC_SValue = SValue
    --     , @c_SC_WSSKIPCANC_Option1 = ISNULL(RTRIM(OPTION1), '')
    --FROM  StorerConfig WITH (NOLOCK)
    --WHERE StorerKey = @c_Storerkey
    -- AND ConfigKey = 'WSSkipCancProcess'

   --kocy02 (s)
   SELECT @n_BackendCancelOrders_Exist = (1)
   FROM  StorerConfig WITH (NOLOCK)
   WHERE StorerKey = @c_Storerkey
   AND (ConfigKey = 'BackendCancelOrders')
   AND SVALUE = '1'
   --kocy02 (e)

   --kocy03 (s)
   SELECT @n_OverAllocationFlag_Exist = (1)
   FROM  StorerConfig WITH (NOLOCK)
   WHERE StorerKey = @c_Storerkey
   AND (ConfigKey = 'ALLOWOVERALLOCATIONS')
   AND SVALUE = '1'
   --kocy03 (e)

   --NJOW01
   IF @c_WSOrdCancMoveToLoc_Opt1 = 'TOLOCBYLOADUDF1'
   BEGIN
   	 IF ISNULL(@c_LPUserDefine01,'') = 'Y'
   	 BEGIN
         SET @c_Move2Loc_Long = ''
         SELECT TOP 1 @c_Move2Loc_Long = ISNULL(RTRIM(Long), '')
         FROM CODELKUP WITH (NOLOCK)
         WHERE ListName = 'WSMove2Loc'
         AND Code = @c_Facility
         AND StorerKey = @c_Storerkey

         IF ISNULL(@c_Move2Loc_Long,'') <> '' AND EXISTS(SELECT 1 FROM LOC(NOLOCK) WHERE Loc = @c_Move2Loc_Long)
            SET @c_ToLoc = @c_Move2Loc_Long
     END
   END

   SELECT @c_DefinedSOStatus = ISNULL(RTRIM(Short), '')
   FROM  CODELKUP WITH (NOLOCK)
   WHERE ListName = 'ORDCANMAP'
   AND Code = N'5'
   AND StorerKey = @c_StorerKey
   
   -- TLTING01  
   SELECT @n_S41_Exists = (1)  
   FROM dbo.CodeLkup WITH (NOLOCK)   
   WHERE LISTNAME = N'S41'  
   AND Storerkey = @c_StorerKey  
   AND code2 = @c_Facility  
   AND Short = 'Y'  
   AND Code = N'SO'  
   
   --(TLTING02) - Start
   SET @n_WSOrdCancMoveCustomized_Exist = 0

   SELECT @n_WSOrdCancMoveCustomized_Exist = (1)
   FROM dbo.StorerConfig WITH (NOLOCK)
   WHERE StorerKey = @c_Storerkey
   AND ConfigKey = N'WSOrdCancMoveCustomized'
   AND SValue = '1'
    
   IF @c_OrderGroup = 'CHILD_ORD'
   BEGIN
      SET @n_AllowCancelCombineOrd = 1


      SELECT TOP 1 @c_ConsoOrderKey = ISNULL(RTRIM(ConsoOrderKey),'')
      FROM OrderDetail WITH (NOLOCK)
      WHERE OrderKey = @c_OrderKey
      SET @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         ROLLBACK TRAN
         SET @n_Err = 80110
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                        + ': Select Orders Detail Fail. '
                        + '. (isp_BackendCancelOrders)'
         GOTO PROCESS_END
      END

      /* Validate Combine Order (Start)            */
      IF @c_ConsoOrderKey <> ''
      BEGIN
         SET @c_ConsoOrd_OrdSts = ''
         SET @c_ConsoOrd_SOSts = ''
         SET @dt_ConsoOrd_AddDate = NULL
         SET @n_RowCNT = 0

         SELECT TOP 1 @c_ConsoOrd_OrdSts = ISNULL(RTRIM(STATUS),'')
               ,@c_ConsoOrd_SOSts = ISNULL(RTRIM(SOSTATUS),'')
               ,@dt_ConsoOrd_AddDate = AddDate
         FROM  ORDERS WITH (NOLOCK)
         WHERE Orderkey = @c_ConsoOrderKey
         AND Storerkey = @c_Storerkey

         SELECT @n_Err = @@ERROR, @n_RowCNT = @@ROWCOUNT
         IF @n_Err <> 0
         BEGIN
            ROLLBACK TRAN
            SET @n_Err = 80111
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                           + ': Select Orders Fail. '
                           + '. (isp_BackendCancelOrders)'
            GOTO PROCESS_END
         END

         IF  @n_RowCNT = 0
         BEGIN
            SET @n_Err = 80111
            SET @c_ErrMsg = 'NSQL'
                           + ': No Parent Conso Orders found. '
                           + '. (isp_BackendCancelOrders)'
            GOTO PROCESS_END
         END

         IF (@c_ConsoOrd_OrdSts < '5')
         OR (@c_ConsoOrd_OrdSts = '5' AND @c_ConsoOrd_SOSts = 'PENDPACK')
         OR (@c_ConsoOrd_OrdSts = '5' AND @c_ConsoOrd_SOSts = 'PENDHOLD')           --(YT02)
         OR (@c_ConsoOrd_OrdSts = '5' AND @c_ConsoOrd_SOSts = 'PENDCANC')
         OR (@c_ConsoOrd_OrdSts = '5' AND @c_ConsoOrd_SOSts = @c_DefinedSOStatus)
         OR (@c_SC_WSFORCECANCORD_SValue = '1') --(CY01)

         BEGIN
            BEGIN TRAN
            UPDATE  ORDERS WITH (ROWLOCK)
            SET EditWho = SUSER_NAME()
               , EditDate = GETDATE()
               , Trafficcop = NULL
               , SOStatus = @c_StatusPENDCANC
            WHERE Orderkey = @c_ConsoOrderKey
            AND Storerkey = @c_Storerkey
            AND Status <> @c_StatusCANC
            SET @n_Err = @@ERROR
            IF @n_Err <> 0
            BEGIN
               ROLLBACK TRAN
               SET @n_Err = 80112
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                              + ': Update Child Orders Fail. '
                              + '. (isp_BackendCancelOrders)'
               GOTO PROCESS_END
            END

            COMMIT TRAN
            BEGIN TRAN

            UPDATE  ORDERS WITH (ROWLOCK)
            SET EditWho = SUSER_NAME()
               , EditDate = GETDATE()
               , Trafficcop = NULL
               , SOStatus = @c_StatusPENDCANC
            WHERE Orderkey = @c_Orderkey
            AND Storerkey = @c_Storerkey
            SET @n_Err = @@ERROR
            IF @n_Err <> 0
            BEGIN
               ROLLBACK TRAN
               SET @n_Err = 80113
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                              + ': Update  Parent Orders Fail. '
                              + '. (isp_BackendCancelOrders)'
               GOTO PROCESS_END
            END
            COMMIT TRAN
         END
         ELSE
         BEGIN
            SET @n_AllowCancelCombineOrd = 0
         END -- IF (@c_ConsoOrd_OrdSts < '5') OR (@c_ConsoOrd_OrdSts = '5' AND @c_ConsoOrd_SOSts = 'PENDPACK')

      END -- @c_ConsoOrderKey <> ''
   END -- @c_OrderGroup = 'CHILD_ORD'
   ELSE
   BEGIN
      IF (@c_OH_Status < '5')
      OR (@c_OH_Status = '5' AND @c_OH_SOStatus = 'PENDPACK')
      OR (@c_OH_Status = '5' AND @c_OH_SOStatus = 'PENDHOLD')                 --(YT02)
      OR (@c_OH_Status = '5' AND @c_OH_SOStatus = 'PENDCANC')
      OR (@c_OH_Status = '5' AND @c_OH_SOStatus = @c_DefinedSOStatus)
      OR (@c_SC_WSFORCECANCORD_SValue = '1') --(CY01)
      BEGIN

         /* Update ORDERS.SOStatus = PENDCANC (Start)         */
         UPDATE  ORDERS WITH (ROWLOCK)
         SET EditWho = SUSER_NAME()
           , EditDate = GETDATE()
           , Trafficcop = NULL
           , SOStatus = @c_StatusPENDCANC
        WHERE Orderkey = @c_Orderkey
         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            ROLLBACK TRAN
            SET @n_Err = 80114
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                           + ': Update Orders Fail. '
                           + '. (isp_BackendCancelOrders)'
            GOTO PROCESS_END
         END
      END    -- @c_OH_Status < '5'
   END   -- ELSE @c_OrderGroup = 'CHILD_ORD'


   IF @c_OrderGroup = 'CHILD_ORD'
   BEGIN
      SET @c_ChildOrderKey = @c_OrderKey
     -- SET @c_OrderKey = @c_Reserved
   END

   IF ISNUMERIC(@c_OH_Status) = 0 --CANC
      AND @n_AllowCancelCombineOrd = 1
   BEGIN
      GOTO CANCEL_CHILD_ORD -- (KH04)
   END


 --IF @c_SC_WSSKIPCANC_SValue = '1'
 --BEGIN
 --   SET @n_Exists = 0
 --   SET @c_ExecStatements = 'SELECT @n_Exists = (1)'
 --         + ' FROM  ORDERS WITH (NOLOCK)'
 --         + ' WHERE Orderkey = @c_OrderKey '
 --         + @c_SC_WSSKIPCANC_OPTION1

 --   SET @c_ExecArguments = '@c_OrderKey          NVARCHAR(10)'
 --         + ',@n_Exists           INT OUTPUT'


 --   EXEC sp_ExecuteSql @c_ExecStatements
 --        , @c_ExecArguments
 --        , @c_OrderKey
 --        , @n_Exists           OUTPUT

 --   IF @n_Exists = 1
 --   BEGIN
 --    SET @n_Err = 80105
 --    SET @c_ErrMsg = 'StorerKey = ' + @c_Storerkey + ', ExternOrderKey = ' + @c_ExternOrderKey +
 --        ', Order Cannot Be Cancelled, WSSkipCancProcess is Setup ' +
 --        '. (isp0000P_WSIML_GENERIC_WMS_CancOrd_Import)'
 --    GOTO PROCESS_END
 --   END
 --  END

   IF @c_OH_Status > '5'
   BEGIN
    --SET @c_InvalidFlag = 'Y'
    --SET @c_InstOutLog = 'Y'
    SET @n_Err = 80106
    SET @c_ErrMsg = 'StorerKey = ' + @c_Storerkey + ', ExternOrderKey = ' + @c_ExternOrderKey +
         ', Order Cannot Be Cancelled, Status = ''' + @c_OH_Status +
         '''. (isp0000P_WSIML_GENERIC_WMS_CancOrd_Import)'
    GOTO PROCESS_END
   END

   IF @n_WSOrdCancMoveToLoc_Exist = 1 OR @n_WSOrdCancMoveToLoc_Task_Exist = 1    --(MC01)
      OR @n_WSOrdCancMoveToLoc_PS_Exist = 1   --(YT01)
      OR @n_BackendCancelOrders_Exist = 1 -- kocy02
   BEGIN
      SET @c_SC_SValue1 = ''
      SELECT @c_SC_SValue1 = SValue
            ,@c_WSOrdCancMoveToLoc_Opt2 = Option2  --NJOW03
      FROM StorerConfig WITH (NOLOCK)
      WHERE StorerKey = @c_Storerkey
      AND ConfigKey = 'WSOrdCancMoveToLoc'
      AND Facility = @c_Facility

      SET @c_SC_SValue3 = ''
      SELECT @c_SC_SValue3 = SValue
      FROM  StorerConfig WITH (NOLOCK)
      WHERE StorerKey = @c_Storerkey
      AND ConfigKey = 'WSOrdCancMovePicked'
      AND Facility = @c_Facility

      --NJOW01
      IF @c_WSOrdCancMoveToLoc_Opt1 = 'TOLOCBYLOADUDF1'
      BEGIN
      	 SET @c_SC_SValue1 = ISNULL(@c_ToLoc,'')
      END

      IF @n_WSOrdCancMoveToLoc_Task_Exist = 1 AND @n_WSOrdCancMoveToLoc_PS_Exist = 1
      BEGIN
         SET @c_SC_SValue1 = ''
      END
      ELSE
      BEGIN
         IF @n_WSOrdCancMoveToLoc_Task_Exist = 1
         BEGIN

            IF ( SELECT   Count(1)
               FROM  PickDetail WITH (NOLOCK)
                  WHERE Orderkey = @c_Orderkey
                  AND   ISNULL(PickSlipNo,'') <> ''   ) = 0 --PK.PickSlipNo is TaskKey
            BEGIN
               SET @c_SC_SValue1 = ''
            END
         END
         IF @n_WSOrdCancMoveToLoc_PS_Exist = 1
         BEGIN
            IF ( SELECT   Count(1)
                  FROM  PickDetail WITH (NOLOCK)
                  WHERE Orderkey = @c_Orderkey
                  AND   (Status = '3' OR Status = '5')  ) = 0
            BEGIN
               SET @c_SC_SValue1 = ''
            END
         END
      END

      /* Insert Temp Table (Start)                */
      IF @c_SC_SValue1 <> ''
      BEGIN

         SET @c_ExecStatements = 'DECLARE C_TempInsert CURSOR FAST_FORWARD READ_ONLY FOR'
                                 + ' SELECT DISTINCT ISNULL(RTRIM(OD.OrderLineNumber), '''')'
                                 + ', ISNULL(RTRIM(PD.SKU), '''')'
                                 + ', ISNULL(RTRIM(PD.Lot), '''')'
                                 + ', ISNULL(RTRIM(PD.Loc), '''')'
                                 + ', ISNULL(RTRIM(PD.ID), '''')'
                                 + ', ISNULL(RTRIM(PD.Qty), '''')'
                                 + ', ISNULL(RTRIM(PD.PickDetailKey), '''')' --NJOW01
                                 + ' FROM  ORDERDETAIL OD WITH (NOLOCK)'
                                 + ' INNER JOIN  PickDetail PD WITH (NOLOCK)'
                                 + ' ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber )'
                               --  + ' AND OD.SKU = PD.SKU AND OD.StorerKey = PD.StorerKey)'
                                 + ' WHERE OD.OrderKey = @c_OrderKey'
                                 + CASE WHEN @c_SC_SValue3 = '1'
                                       THEN ' AND PD.Status = ''5'' '
                                    ELSE ''
                                 END
                                 +  CASE WHEN @n_WSOrdCancMoveToLoc_PS_Exist = 1
                                       THEN ' AND ( PD.Status = ''3'' OR PD.Status = ''5'') '  --CY03
                                    ELSE ''
                                    END
                              + CASE WHEN @n_WSOrdCancMoveToLoc_Task_Exist = 1
                                       THEN ' AND PD.PickSlipNo <> '''' '
                                 ELSE ''
                                 END
                                 + ' ORDER BY ISNULL(RTRIM(OD.OrderLineNumber), '''')'

         SET @c_ExecArguments = N'@c_Orderkey NVARCHAR(10)'

         EXEC sp_ExecuteSql @c_ExecStatements
                           , @c_ExecArguments
                           , @c_Orderkey
         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            ROLLBACK TRAN
            SET @n_Err = 80116
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                           + ': Select Order detail cursor Fail. '
                           + '. (isp_BackendCancelOrders)'
            GOTO PROCESS_END
         END

         OPEN C_TempInsert
         FETCH NEXT FROM C_TempInsert INTO @c_OD_OrderLineNumber
                                          ,@c_PD_SKU
                                          ,@c_PD_Lot
                                          ,@c_PD_Loc
                                          ,@c_PD_ID
                                          ,@n_PD_Qty
                                          ,@c_PD_PickDetailKey --NJOW02

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @c_From_Loc = @c_PD_Loc
            SET @c_From_ID = @c_PD_ID
            SET @c_To_Loc = ''
            SET @c_To_ID = ''

            /*Follow the logic below
            -----------------------------------------------
            Location Type  | Virtual   | Pick   | Original
            -----------------------------------------------
            Pick           | N         | N      | N
            -----------------------------------------------
            Bulk           | Y         | Y      | N
            -----------------------------------------------
            */

            --Check Sku From Pick Location Or Bulk Location
            /*********************************************/
            /* Get LocationType (Start)                 */
            /*********************************************/
            SET @c_SL_LocationType = ''
            SELECT @c_SL_LocationType = ISNULL(RTRIM(LocationType), '')
            FROM  SKUxLOC WITH (NOLOCK)
            WHERE SKU = @c_PD_SKU
            AND StorerKey = @c_Storerkey
            AND Loc = @c_PD_Loc
            SET @n_Err = @@ERROR
            IF @n_Err <> 0
            BEGIN
               ROLLBACK TRAN
               SET @n_Err = 80117
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                              + ': Select SKUXLOC table Fail. '
                              + '. (isp_BackendCancelOrders)'
               GOTO PROCESS_END
            END

            SET @c_Loc_LocationType = ''
            SELECT @c_Loc_LocationType = ISNULL(RTRIM(LocationType), '')
            FROM  LOC WITH (NOLOCK)
            WHERE Loc = @c_PD_Loc
            SET @n_Err = @@ERROR
            IF @n_Err <> 0
            BEGIN
               ROLLBACK TRAN
               SET @n_Err = 80118
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                              + ': Select LOC table Fail. '
                              + '. (isp_BackendCancelOrders)'
               GOTO PROCESS_END
            END

          /*kocy03 (s)*/
             SET @c_LLI_QtyExpected = ''
             SELECT @c_LLI_QtyExpected = ISNULL(RTRIM(QtyExpected), '')
             FROM LOTxLOCxID WITH (NOLOCK)
             WHERE LOT = @c_PD_Lot
             AND LOC = @c_PD_Loc
             AND ID = @c_PD_ID
              SET @n_Err = @@ERROR
            IF @n_Err <> 0
            BEGIN
               ROLLBACK TRAN
               SET @n_Err = 80118
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                              + ': Select LOTxLOCxID table Fail. '
                              + '. (isp_BackendCancelOrders)'
               GOTO PROCESS_END
            END
            /*kocy03 (e) */


            /*********************************************/
            /* Get LocationType (End)                   */
            /*********************************************/
            /* Verify Based On Location Type (Start)    */
            /*********************************************/

            /*
            IF @c_SL_LocationType IN ('CASE', 'PICK')  AND @n_OverAllocationFlag_Exist = 1
            BEGIN
               GOTO NEXT_PICKDETAIL_RECORD
            END
            ELSE
            BEGIN
               IF @c_Loc_LocationType IN ('DYNPICKP', 'DYNPICKR') AND @c_LLI_QtyExpected > 0
                  GOTO NEXT_PICKDETAIL_RECORD
            END*/

            --NJOW03
            IF @c_WSOrdCancMoveToLoc_Opt2 = '' OR @c_SL_LocationType <> @c_WSOrdCancMoveToLoc_Opt2
            BEGIN
               IF @c_SL_LocationType IN ('CASE', 'PICK') AND @n_OverAllocationFlag_Exist = 1  --(CY09)
               BEGIN
                  GOTO NEXT_PICKDETAIL_RECORD
               END
               ELSE
               BEGIN
                  IF @c_Loc_LocationType IN ('DYNPICKP', 'DYNPICKR') AND @c_LLI_QtyExpected > 0  --(CY09)
                     GOTO NEXT_PICKDETAIL_RECORD
               END
            END
            ELSE IF @c_LLI_QtyExpected > 0
            BEGIN
               GOTO NEXT_PICKDETAIL_RECORD
            END

            /*********************************************/
            /* Verify Based On Location Type (End)      */
            /*********************************************/

            --NJOW01
            IF @c_WSOrdCancMoveToLoc_Opt1 = 'TOLOCBYLOADUDF1'
            BEGIN
      	       SET @c_To_Loc = ISNULL(@c_SC_SValue1,'')
            END

            IF @c_SC_SValue1 = 'PCK_LOC'
            BEGIN
               --Get Pick Location
               SET @c_SL_Loc = ''
               SELECT @c_SL_Loc = ISNULL(RTRIM(SL.Loc), '')
                  FROM  SKUxLOC SL WITH (NOLOCK)
                  INNER JOIN  LOC Loc WITH (NOLOCK)
                  ON (SL.Loc = Loc.Loc AND SL.LocationType = Loc.LocationType)
                  WHERE SL.Sku = @c_PD_SKU
                  AND SL.StorerKey = @c_Storerkey
                AND Loc.LocationType = 'PICK'
                  AND Loc.Facility = @c_Facility
                  SET @n_Err = @@ERROR
                  IF @n_Err <> 0
                  BEGIN
                     ROLLBACK TRAN
                     SET @n_Err = 80119
                    SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                                    + ': Select SKUXLOC table Fail. '
                                    + '. (isp_BackendCancelOrders)'
                     GOTO PROCESS_END
                  END


               IF @c_SL_Loc <> ''
                  SET @c_To_Loc = @c_SL_Loc
            END --IF @c_SC_SValue1 = 'PCK_LOC'
            
            IF @c_SC_SValue1 = 'TMP_LOC'
            BEGIN
               --(TLTING02) Start
               IF @n_WSOrdCancMoveCustomized_Exist = 1 
               BEGIN
                  IF CURSOR_STATUS('LOCAL' , 'C_CodeLkup_GetShort') in (0 , 1)
                  BEGIN
                     CLOSE C_CodeLkup_GetShort
                     DEALLOCATE C_CodeLkup_GetShort
                  END

                  DECLARE C_CodeLkup_GetShort CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT ISNULL(RTRIM(Notes2),'')  --Customer Condition
                        ,ISNULL(RTRIM(Long),'')   --ToLoc
                  FROM   dbo.CODELKUP WITH (NOLOCK)
                  WHERE LISTNAME = N'WSMV2LocCZ'  
                  AND Code = @c_Facility
                  AND Storerkey = @c_Storerkey

                  OPEN C_CodeLkup_GetShort  
                  FETCH NEXT FROM C_CodeLkup_GetShort INTO @c_CLK_WSMove2LocCustomized_Notes2
                                                         , @c_CLK_WSMove2LocCustomized_Long
                  WHILE @@FETCH_STATUS <> -1   
                  BEGIN
                           
                     SET @n_Exists = 0
                     SET @c_ExecStatements = ' SELECT @n_Exists = (1)'
                                             + ' FROM dbo.Orders WITH (NOLOCK)'
                                             + ' WHERE OrderKey  = @c_Orderkey '
                                             +  @c_CLK_WSMove2LocCustomized_Notes2

                     SET @c_ExecArguments = '@c_Orderkey       NVARCHAR(10)'
                                          + ',@n_Exists        INT OUTPUT' 

                     EXEC sp_ExecuteSql @c_ExecStatements 
                                       , @c_ExecArguments  
                                       , @c_Orderkey   
                                       , @n_Exists           OUTPUT
                           
                     IF @n_Exists > 0
                     BEGIN
                        SET @c_To_Loc = @c_CLK_WSMove2LocCustomized_Long
                     END
                           
                     FETCH NEXT FROM C_CodeLkup_GetShort INTO @c_CLK_WSMove2LocCustomized_Notes2
                                                            , @c_CLK_WSMove2LocCustomized_Long
                  END -- WHILE @@FETCH_STATUS <> -1   
                  CLOSE C_CodeLkup_GetShort  
                  DEALLOCATE C_CodeLkup_GetShort
               END
               ELSE
               BEGIN
               --(TLTING02) End  

                  IF @c_SL_LocationType = ''
                     SET @c_SL_LocationType = @c_Loc_LocationType

                  /*********************************************/
                  /* Get Codelkup Location (Start)            */
                  /*********************************************/
                  SET @c_Move2Loc_Long = ''
                  SET @c_Move2Loc_Short = ''       --YT01
                  SET @c_Move2Loc_UDF01 = ''  --NJOW04
                  SELECT @c_Move2Loc_Long = ISNULL(RTRIM(Long), '')
                        , @c_Move2Loc_Short = ISNULL(RTRIM(Short), '')
                        , @c_Move2Loc_UDF01 = ISNULL(RTRIM(UDF01), '') --NJOW04
                  FROM CODELKUP WITH (NOLOCK)
                  WHERE ListName = N'WSMove2Loc'
                     AND Code = @c_Facility
                     AND Code2 = @c_SL_LocationType
                     AND StorerKey = @c_Storerkey

                  --NJOW04
                  IF @c_WSOrdCancMoveToLoc_Opt3 = '1' AND @c_ECOM_PRESALE_FLAG <> ''
                  BEGIN
                     IF @c_Move2Loc_UDF01 <> ''
               	        SET @c_To_Loc = @c_Move2Loc_UDF01
                  END
                  ELSE
                  BEGIN
                     IF @c_Move2Loc_Long <> ''
                        SET @c_To_Loc = @c_Move2Loc_Long
                  END

                  --YT01-S
                  IF @c_Move2Loc_Short <> ''
                     SET @c_To_ID = @c_Move2Loc_Short
                  --YT01-E
                  /*********************************************/
                  /* Get Codelkup Location (End)              */
                  /*********************************************/
               END -- TLTING02
            END --IF @c_SC_SValue1 = 'TMP_LOC'

            IF @c_To_Loc <> ''
            BEGIN
               INSERT INTO #TempMoveRecord
               (
                  OrderLineNumber, SKU, Lot, FromLoc, FromID, ToLoc, ToID, Qty,
                  PickDetailKey --NJOW02
               )
               VALUES
               (
                  @c_OD_OrderLineNumber, @c_PD_SKU, @c_PD_Lot, @c_From_Loc, @c_From_ID, @c_To_Loc, @c_To_ID, @n_PD_Qty,
                  @c_PD_PickDetailKey  --NJOW02

               )
            END --IF @c_To_Loc <> ''

    NEXT_PICKDETAIL_RECORD:

            FETCH NEXT FROM C_TempInsert INTO @c_OD_OrderLineNumber
                                             ,@c_PD_SKU
                                             ,@c_PD_Lot
                                             ,@c_PD_Loc
                                             ,@c_PD_ID
                                             ,@n_PD_Qty
                                             ,@c_PD_PickDetailKey --NJOW02

         END -- WHILE @@FETCH_STATUS <> -1
         CLOSE C_TempInsert
         DEALLOCATE C_TempInsert
      END --IF @c_SC_SValue1 <> ''

      /*********************************************/
      /* Insert Temp Table (End)                  */
      /*********************************************/
   END --IF @n_WSOrdCancMoveToLoc_Exist = 1
   /*********************************************/
   /* Generate Temp Move Record (End)           */

   IF @c_OH_Status > '0'
   BEGIN

      BEGIN TRAN -- kocy(s)
        UPDATE ORDERS WITH (ROWLOCK)
         SET  EditDate = GETDATE()
      WHERE Orderkey = @c_Orderkey
      SET @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         ROLLBACK TRAN
         SET @n_Err = 80125
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                        + ': Update ORDERS Fail. '
                        + '. (isp_BackendCancelOrders)'
         GOTO PROCESS_END
      END
      COMMIT TRAN  -- kocy(e)

      BEGIN TRAN
      DECLARE C_PickingInfo_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickHeaderKey
      FROM  PickHeader WITH (NOLOCK)
      WHERE Orderkey = @c_Orderkey
      ORDER BY PickHeaderKey

      OPEN C_PickingInfo_Delete
      FETCH NEXT FROM C_PickingInfo_Delete INTO @c_PickHeaderKey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DELETE  PickingInfo
         WHERE PickSlipNo = @c_PickHeaderKey
         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            ROLLBACK TRAN
          SET @n_Err = 80120
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                           + ': Delete PickingInfo Fail. '
                           + '. (isp_BackendCancelOrders)'
            GOTO PROCESS_END
         END

         FETCH NEXT FROM C_PickingInfo_Delete INTO @c_PickHeaderKey
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE C_PickingInfo_Delete
      DEALLOCATE C_PickingInfo_Delete

      COMMIT TRAN

      BEGIN TRAN

      DECLARE C_PickDetail_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PickDetailKey
         FROM  PickDetail WITH (NOLOCK)
         WHERE Orderkey = @c_Orderkey
         ORDER BY PickDetailKey

      OPEN C_PickDetail_Delete
      FETCH NEXT FROM C_PickDetail_Delete INTO @c_PickDetailKey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         BEGIN TRAN
         DELETE PickDetail WHERE PickDetailKey = @c_PickDetailKey
         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            ROLLBACK TRAN
            SET @n_Err = 80124
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                           + ': Delete PickDetail Fail. '
                           + '. (isp_BackendCancelOrders)'
            GOTO PROCESS_END
         END
         COMMIT TRAN
         FETCH NEXT FROM C_PickDetail_Delete INTO @c_PickDetailKey
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE C_PickDetail_Delete
      DEALLOCATE C_PickDetail_Delete

      COMMIT TRAN

      BEGIN TRAN

      DECLARE C_PackInfo_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT A.PickSlipNo, A.CartonNo
      FROM  PackInfo A WITH (NOLOCK)
      INNER JOIN  PackHeader B WITH (NOLOCK) ON A.PickSlipNo = B.PickSlipNo
      WHERE B.OrderKey = @c_Orderkey
      AND B.StorerKey = @c_StorerKey
      ORDER BY A.PickSlipNo, A.CartonNo

      OPEN C_PackInfo_Delete
      FETCH NEXT FROM C_PackInfo_Delete INTO @c_PickSlipNo, @n_CartonNo

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DELETE  PackInfo  WHERE PickSlipNo = @c_PickSlipNo AND CartonNo = @n_CartonNo
         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            ROLLBACK TRAN
            SET @n_Err = 80126
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                           + ': Delete PackInfo Fail. '
                           + '. (isp_BackendCancelOrders)'
            GOTO PROCESS_END
         END

         FETCH NEXT FROM C_PackInfo_Delete INTO @c_PickSlipNo, @n_CartonNo
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE C_PackInfo_Delete
      DEALLOCATE C_PackInfo_Delete

      COMMIT TRAN

      BEGIN TRAN

      DECLARE C_PackHeader_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickSlipNo
      FROM  PackHeader WITH (NOLOCK)
      WHERE OrderKey = @c_Orderkey
      AND StorerKey = @c_StorerKey
      ORDER BY PickSlipNo

      OPEN C_PackHeader_Delete
      FETCH NEXT FROM C_PackHeader_Delete INTO @c_PickSlipNo

      WHILE @@FETCH_STATUS <> -1
      BEGIN
      	 --NJOW06
      	 UPDATE Packheader WITH (ROWLOCK)
         SET Status = '0',
             ArchiveCop = NULL
         WHERE Pickslipno = @c_Pickslipno

         DECLARE C_PackDetail_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT CartonNo, LabelNo, LabelLine
         FROM  PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @c_PickSlipNo
         ORDER BY CartonNo
         OPEN C_PackDetail_Delete
         FETCH NEXT FROM C_PackDetail_Delete INTO @n_CartonNo, @c_LabelNo, @c_LabelLine

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            DELETE  PackDetail WHERE PickSlipNo = @c_PickSlipNo AND CartonNo = @n_CartonNo
               AND LabelNo = @c_LabelNo AND LabelLine = @c_LabelLine
            SET @n_Err = @@ERROR
            IF @n_Err <> 0
            BEGIN
               ROLLBACK TRAN
               SET @n_Err = 80127
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                              + ': Delete PackDetail Fail. '
                              + '. (isp_BackendCancelOrders)'
               GOTO PROCESS_END
            END

            FETCH NEXT FROM C_PackDetail_Delete INTO @n_CartonNo, @c_LabelNo, @c_LabelLine
         END -- WHILE @@FETCH_STATUS <> -1
         CLOSE C_PackDetail_Delete
         DEALLOCATE C_PackDetail_Delete

         DELETE  PackHeader  WHERE PickSlipNo = @c_PickSlipNo

         FETCH NEXT FROM C_PackHeader_Delete INTO @c_PickSlipNo
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE C_PackHeader_Delete
      DEALLOCATE C_PackHeader_Delete

      COMMIT TRAN

      --NJOW06 S
      BEGIN TRAN
      DECLARE C_PackSerialNo_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PackSerialNo.PackSerialNoKey
         FROM  PickHeader WITH (NOLOCK)
         JOIN PackSerialNo WITH (NOLOCK) ON PickHeader.Pickheaderkey = PackSerialNo.PickslipNo
         WHERE PickHeader.Orderkey = @c_Orderkey
         ORDER BY PackSerialNo.PackSerialNoKey

      OPEN C_PackSerialNo_Delete
      FETCH NEXT FROM C_PackSerialNo_Delete INTO @n_PackSerialNoKey

      WHILE @@FETCH_STATUS <> -1
      BEGIN     	          	 
         DELETE PACKSERIALNO
         WHERE PackSerialNoKey = @n_PackSerialNoKey
         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            ROLLBACK TRAN
            SET @n_Err = 80128
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                           + ': Delete PackSerialNo Fail. '
                           + '. (isp_BackendCancelOrders)'

            CLOSE C_PackSerialNo_Delete
            DEALLOCATE C_PackSerialNo_Delete

            GOTO PROCESS_END
         END

         FETCH NEXT FROM C_PackSerialNo_Delete INTO @n_PackSerialNoKey
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE C_PackSerialNo_Delete
      DEALLOCATE C_PackSerialNo_Delete
      
      COMMIT TRAN
      --NJOW06 S


      --NJOW06 Move down from above delete pack 
      BEGIN TRAN

      DECLARE C_PickHeader_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickHeaderKey
      FROM  PickHeader WITH (NOLOCK)
      WHERE Orderkey = @c_Orderkey
      ORDER BY PickHeaderKey

      OPEN C_PickHeader_Delete
      FETCH NEXT FROM C_PickHeader_Delete INTO @c_PickHeaderKey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DELETE  PickHeader  WHERE PickHeaderKey = @c_PickHeaderKey
         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            ROLLBACK TRAN
            SET @n_Err = 80125
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                           + ': Delete PickHeader Fail. '
                           + '. (isp_BackendCancelOrders)'
            GOTO PROCESS_END
         END
         FETCH NEXT FROM C_PickHeader_Delete INTO @c_PickHeaderKey
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE C_PickHeader_Delete
      DEALLOCATE C_PickHeader_Delete

      COMMIT TRAN

      /* Update Order Status = 0 (Start)          */
      UPDATE ORDERS WITH (ROWLOCK)
         SET EditWho = SUSER_NAME()
            , EditDate = GETDATE()
            , Trafficcop = NULL
            , Status =  '0'  -- @c_OrderStatus
      WHERE Orderkey = @c_Orderkey
      SET @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         ROLLBACK TRAN
         SET @n_Err = 80129
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                        + ': Update ORDERS Fail. '
                        + '. (isp_BackendCancelOrders)'
         GOTO PROCESS_END
      END

      IF EXISTS(SELECT 1 FROM #TempMoveRecord WITH (NOLOCK))
      BEGIN
         DECLARE C_TempMoveRecord_Loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT PickDetailKey --NJOW02
         FROM #TempMoveRecord WITH (NOLOCK)
         ORDER BY PickDetailKey
         --SELECT DISTINCT OrderLineNumber
         --FROM #TempMoveRecord WITH (NOLOCK)
         --ORDER BY OrderLineNumber


         OPEN C_TempMoveRecord_Loop
         FETCH NEXT FROM C_TempMoveRecord_Loop INTO @c_Temp_PickDetailKey  --NJOW02
         --FETCH NEXT FROM C_TempMoveRecord_Loop INTO @c_Temp_OrderLineNumber
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            BEGIN TRAN

            SET @c_Temp_Sku = ''
            SET @c_Temp_Lot = ''
            SET @c_Temp_ToLoc = ''
            SET @n_Temp_Qty = 0
            SET @dt_Temp_Datetime = GETDATE()

            SELECT @c_Temp_Sku = ISNULL(RTRIM(SKU), '')
                  ,@c_Temp_Lot = ISNULL(RTRIM(Lot), '')
                  ,@c_Temp_FromLoc = ISNULL(RTRIM(FromLoc), '')
                  ,@c_Temp_FromID = ISNULL(RTRIM(FromID), '')
                  ,@c_Temp_ToLoc = ISNULL(RTRIM(ToLoc), '')
                  ,@c_Temp_ToID = ISNULL(RTRIM(ToID), '')
                  ,@n_Temp_Qty = Qty
            FROM #TempMoveRecord WITH (NOLOCK)
            WHERE PickDetailKey = @c_Temp_PickDetailKey    --NJOW02
            --WHERE OrderLineNumber = @c_Temp_OrderLineNumber
                       
            -- TLTING01 START  
            IF @n_S41_Exists > 0  
            BEGIN  
                        
               SET @c_lottable01  = ''  
               SET @c_lottable02  = ''  
               SET @c_lottable03  = ''  
               SET @d_lottable04  = NULL  
               SET @d_lottable05  = NULL  
               SET @c_Lottable06  = ''  
               SET @c_Lottable07  = ''  
               SET @c_Lottable08  = ''  
               SET @c_Lottable09  = ''  
               SET @c_Lottable10  = ''  
               SET @c_Lottable11  = ''  
               SET @c_Lottable12  = ''  
               SET @d_Lottable13  = NULL  
               SET @d_Lottable14  = NULL  
               SET @d_Lottable15  = NULL  
  
               SELECT @c_lottable01 = Lottable01  
                     , @c_lottable02 = lottable02  
                     , @c_lottable03 = lottable03  
                     , @d_lottable04 = lottable04  
                     , @d_lottable05 = lottable05  
                     , @c_Lottable06 = lottable06  
                     , @c_Lottable07 = lottable07  
                     , @c_Lottable08 = lottable08  
                     , @c_Lottable09 = lottable09  
                     , @c_Lottable10 = lottable10  
                     , @c_Lottable11 = lottable11  
                     , @c_Lottable12 = lottable12  
                     , @d_Lottable13 = lottable13  
                     , @d_Lottable14 = lottable14  
                     , @d_Lottable15 = lottable15  
               FROM dbo.LOTATTRIBUTE WITH (NOLOCK)   
               WHERE Lot = @c_Temp_Lot  
                                 
               EXEC nspItrnAddWithdrawal   
                     @n_ItrnSysId  = NULL,  
                     @c_StorerKey  = @c_StorerKey,  
                     @c_Sku        = @c_Temp_Sku,  
                     @c_Lot        = @c_Temp_Lot,  
                     @c_ToLoc      = @c_Temp_FromLoc,    
                     @c_ToID       = @c_Temp_FromID,  
                     @c_Status     = '',   
                     @c_lottable01 = @c_lottable01,  
                     @c_lottable02 = @c_lottable02,    
                     @c_lottable03 = @c_lottable03,    
                     @d_lottable04 = @d_lottable04,    
                     @d_lottable05 = @d_lottable05,    
                     @c_Lottable06 = @c_Lottable06,    
                     @c_Lottable07 = @c_Lottable07,    
                     @c_Lottable08 = @c_Lottable08,    
                     @c_Lottable09 = @c_Lottable09,    
                     @c_Lottable10 = @c_Lottable10,    
                     @c_Lottable11 = @c_Lottable11,    
                     @c_Lottable12 = @c_Lottable12,    
                     @d_Lottable13 = @d_Lottable13,    
                     @d_Lottable14 = @d_Lottable14,    
                     @d_Lottable15 = @d_Lottable15,    
                     @c_Channel    = '',   
                     @n_Channel_ID = @n_Channel_ID OUTPUT,  
                     @n_casecnt    = 0,    
                     @n_innerpack  = 0,    
                     @n_Qty        = @n_Temp_Qty, 
                     @n_pallet     = 0,   
                     @f_cube       = 0,   
                     @f_grosswgt   = 0,   
                     @f_netwgt     = 0,   
                     @f_otherunit1 = 0,   
                     @f_otherunit2 = 0,   
                     @c_SourceKey  = @c_Temp_PickDetailKey,  
                     @c_SourceType = 'isp_BackendCancelOrders',    
                     @c_PackKey    = '',   
                     @c_UOM        = '',   
                     @b_UOMCalc    = 0,  
                     @d_EffectiveDate = @dt_Temp_Datetime,    
                     @c_ItrnKey    = '',     
                     @b_Success    = @b_Success OUTPUT,    
                     @n_err        = @n_Err     OUTPUT,    
                     @c_errmsg     = @c_ErrMsg  OUTPUT   
               IF @b_Success = 0
               BEGIn
                  SET @n_continue = 3
                  ROLLBACK TRAN
                  GOTO PROCESS_END
               END
               IF @b_Debug = 1  
               BEGIN  
                  PRINT '[isp_BackendCancelOrders]:  ItrnAddWithdrawal '   
  
               END  
   
  
               EXEC dbo.nspItrnAddDeposit 
                     @n_ItrnSysId  = NULL,  
                     @c_StorerKey  = @c_StorerKey,  
                     @c_Sku        = @c_Temp_Sku,  
                     @c_Lot        = '',  
                     @c_ToLoc      = @c_Temp_ToLoc,    
                     @c_ToID       = @c_Temp_ToID,  
                     @c_Status     = '',   
                     @c_lottable01 = @c_lottable01,  
                     @c_lottable02 = @c_lottable02,    
                     @c_lottable03 = @c_lottable03,    
                     @d_lottable04 = @d_lottable04,    
                     @d_lottable05 = @d_lottable05,    
                     @c_Lottable06 = @c_Lottable06,    
                     @c_Lottable07 = @c_ExternOrderKey,    --
                     @c_Lottable08 = @c_Lottable08,    
                     @c_Lottable09 = @c_Lottable09,    
                     @c_Lottable10 = @c_Lottable10,    
                     @c_Lottable11 = 'P',                   --
                     @c_Lottable12 = @c_Lottable12,    
                     @d_Lottable13 = @d_Lottable13,    
                     @d_Lottable14 = @d_Lottable14,    
                     @d_Lottable15 = @d_Lottable15,    
                     @c_Channel    = '',   
                     @n_Channel_ID = @n_Channel_ID OUTPUT,  
                     @n_casecnt    = 0,    
                     @n_innerpack  = 0,    
                     @n_Qty        = @n_Temp_Qty,    
                     @n_pallet     = 0,   
                     @f_cube       = 0,   
                     @f_grosswgt   = 0,   
                     @f_netwgt     = 0,   
                     @f_otherunit1 = 0,   
                     @f_otherunit2 = 0,   
                     @c_SourceKey  = @c_Temp_PickDetailKey,  
                     @c_SourceType = 'isp_BackendCancelOrders',    
                     @c_PackKey    = '',   
                     @c_UOM        = '',   
                     @b_UOMCalc    = 0,  
                     @d_EffectiveDate = @dt_Temp_Datetime,    
                     @c_ItrnKey    = '',     
                     @b_Success    = @b_Success OUTPUT,    
                     @n_err        = @n_Err     OUTPUT,    
                     @c_errmsg     = @c_ErrMsg  OUTPUT    
               IF @b_Success = 0
               BEGIn
                  SET @n_continue = 3
                  ROLLBACK TRAN
                  GOTO PROCESS_END
               END    
               IF @b_Debug = 1  
               BEGIN  
                  PRINT '[isp_BackendCancelOrders]: ItrnAddDeposit '   
               END  
   
            END  
            ELSE  
            BEGIN  
            -- TLTING01 END     

               EXEC  nspItrnAddMove
                  NULL
                  ,@c_StorerKey
                  ,@c_Temp_Sku
                  ,@c_Temp_Lot
                  ,@c_Temp_FromLoc
                  ,@c_Temp_FromID
                  ,@c_Temp_ToLoc
                  ,@c_Temp_ToID --@c_ToID
                  ,NULL
                  ,'' --@c_lottable01
                  ,'' --@c_lottable02
                  ,'' --@c_lottable03
                  ,NULL --@d_lottable04
                  ,NULL  --@d_lottable05
                  ,''    --@c_lottable06
                  ,''    --@c_lottable07
                  ,''    --@c_lottable08
                  ,''    --@c_lottable09
                  ,''    --@c_lottable10
                  ,''    --@c_lottable11
                  ,''    --@c_lottable12
                  ,NULL  --@d_lottable13
                  ,NULL  --@d_lottable14
                  ,NULL  --@d_lottable15
                  ,0
                  ,0
                  ,@n_Temp_Qty  --@n_qty
                  ,0
                  ,0
                  ,0
                  ,0
                  ,0
                  ,0
                  ,''
                  ,'isp_BackendCancelOrders'   -- TLTING01
                  ,'' --@c_PackKey
                  ,''  --@c_UOM
                  ,1
                  ,@dt_Temp_Datetime --@d_today
                  ,'' --@c_itrnkey
                  ,@b_Success OUTPUT
                  ,@n_Err OUTPUT
                  ,@c_ErrMsg OUTPUT

                  IF @b_Success = 0
                  BEGIn
                     SET @n_continue = 3
                     ROLLBACK TRAN
                  END
               END -- TLTING01

               COMMIT TRAN

            FETCH NEXT FROM C_TempMoveRecord_Loop INTO @c_Temp_PickDetailKey  --NJOW02
            --FETCH NEXT FROM C_TempMoveRecord_Loop INTO @c_Temp_OrderLineNumber
         END -- WHILE @@FETCH_STATUS <> -1
         CLOSE C_TempMoveRecord_Loop
         DEALLOCATE C_TempMoveRecord_Loop

         TRUNCATE TABLE #TempMoveRecord
      END
      /*********************************************/
    /* Generate Move Back To Inventory (End)    */
      /*********************************************/
   END --IF @c_OrderStatus > '0'

   /* Delete PreAllocatePickDetail (Start)      */
   IF @c_SC_SValue = '0' OR @c_SC_SValue = ''
   BEGIN

      DECLARE C_PreAllocatePickDetail_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PreAllocatePickDetailKey
      FROM  PreAllocatePickDetail WITH (NOLOCK)
      WHERE Orderkey = @c_Orderkey
      AND StorerKey = @c_StorerKey
      ORDER BY PreAllocatePickDetailKey

      OPEN C_PreAllocatePickDetail_Delete
      FETCH NEXT FROM C_PreAllocatePickDetail_Delete INTO @c_PreAllocatePickDetailKey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DELETE  PreAllocatePickDetail  WHERE PreAllocatePickDetailKey = @c_PreAllocatePickDetailKey
         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SET @n_Err = 80130
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                           + ': Delete PreAllocatePickDetail Fail. '
                           + '. (isp_BackendCancelOrders)'
            GOTO PROCESS_END
         END
         FETCH NEXT FROM C_PreAllocatePickDetail_Delete INTO @c_PreAllocatePickDetailKey
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE C_PreAllocatePickDetail_Delete
      DEALLOCATE C_PreAllocatePickDetail_Delete
   END  -- @c_SC_SValue = '0' OR @c_SC_SValue = ''
   /* Delete PreAllocatePickDetail (End)        */

   BEGIN TRAN
   DECLARE C_LoadPlanDetail_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT LoadKey, LoadLineNumber
   FROM  LoadPlanDetail WITH (NOLOCK)
   WHERE OrderKey = @c_Orderkey
   ORDER BY LoadKey , LoadLineNumber

   OPEN C_LoadPlanDetail_Delete
   FETCH NEXT FROM C_LoadPlanDetail_Delete INTO @c_LoadKey, @c_LoadLineNumber

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      DELETE  LoadPlanDetail  WHERE LoadKey = @c_LoadKey AND LoadLineNumber = @c_LoadLineNumber
      SET @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         ROLLBACK TRAN
         SET @n_Err = 80131
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                        + ': Delete LoadPlanDetail Fail. '
                        + '. (isp_BackendCancelOrders)'
         GOTO PROCESS_END
      END
      FETCH NEXT FROM C_LoadPlanDetail_Delete INTO @c_LoadKey, @c_LoadLineNumber
   END -- WHILE @@FETCH_STATUS <> -1
   CLOSE C_LoadPlanDetail_Delete
   DEALLOCATE C_LoadPlanDetail_Delete

   COMMIT TRAN

   -- kocy04(s)
 /*  BEGIN TRAN

   DECLARE C_WaveDetail_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT WaveKey
   FROM  WAVEDETAIL WITH (NOLOCK)
   WHERE OrderKey = @c_Orderkey
   ORDER BY WaveKey

   OPEN C_WaveDetail_Delete
   FETCH NEXT FROM C_WaveDetail_Delete INTO @c_WaveKey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      DELETE  WAVEDETAIL  WHERE WaveKey = @c_WaveKey
      SET @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         ROLLBACK TRAN
         SET @n_Err = 80140
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                        + ': Delete WaveDetail Fail. '
                        + '. (isp_BackendCancelOrders)'
         GOTO PROCESS_END
      END
      FETCH NEXT FROM C_WaveDetail_Delete INTO @c_WaveKey
   END -- WHILE @@FETCH_STATUS <> -1
   CLOSE C_WaveDetail_Delete
   DEALLOCATE C_WaveDetail_Delete

   COMMIT TRAN
   --kocy04(E)
 */

   DECLARE C_CartonTrackList_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRef
   FROM  CartonTrack WITH (NOLOCK)
   WHERE LabelNo = @c_Orderkey
   ORDER BY RowRef


   OPEN C_CartonTrackList_Delete
   FETCH NEXT FROM C_CartonTrackList_Delete INTO @n_RowRef

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      --(KT03) - Start
/*          SET @c_CT_TrackingNo = ''
      SET @c_CT_EditWho = ''
      SET @c_CT_EditDate = ''

      SELECT @c_CT_TrackingNo = ISNULL(RTRIM(TrackingNo), '')
         ,@c_CT_EditWho = ISNULL(RTRIM(EditWho), '')
         ,@c_CT_EditDate = CONVERT(NVARCHAR(30), EditDate, 120)
      FROM  CartonTrack WITH (NOLOCK)
      WHERE RowRef = @n_RowRef

*/
      BEGIN TRAN
      UPDATE  CartonTrack WITH (ROWLOCK)
      SET LabelNo = ''
         ,CarrierRef2 = 'PEND'
         ,EditDate = GETDATE()
         ,EditWho = SUSER_NAME()
      WHERE RowRef = @n_RowRef
      SET @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         ROLLBACK TRAN
         SET @n_Err = 80132
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                        + ': Update CartonTrack Fail. '
            + '. (isp_BackendCancelOrders)'
         GOTO PROCESS_END
      END
      COMMIT TRAN

      FETCH NEXT FROM C_CartonTrackList_Delete INTO @n_RowRef
   END -- WHILE @@FETCH_STATUS <> -1
   CLOSE C_CartonTrackList_Delete
   DEALLOCATE C_CartonTrackList_Delete

   DECLARE C_rdtTrackLog_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRef
   FROM  RDT.rdtTrackLog WITH (NOLOCK)
   WHERE OrderKey = @c_Orderkey
   AND StorerKey = @c_StorerKey
   ORDER BY RowRef

   OPEN C_rdtTrackLog_Delete
   FETCH NEXT FROM C_rdtTrackLog_Delete INTO @n_RowRef

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      DELETE  RDT.rdtTrackLog WHERE RowRef = @n_RowRef
      SET @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         ROLLBACK TRAN
         SET @n_Err = 80133
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                        + ': DELETE rdtTrackLog Fail. '
                        + '. (isp_BackendCancelOrders)'
         GOTO PROCESS_END
      END
      FETCH NEXT FROM C_rdtTrackLog_Delete INTO @n_RowRef
   END -- WHILE @@FETCH_STATUS <> -1
   CLOSE C_rdtTrackLog_Delete
   DEALLOCATE C_rdtTrackLog_Delete

   BEGIN TRAN
 UPDATE  ORDERS WITH (ROWLOCK)
   SET EditWho = SUSER_NAME()
      , EditDate = GETDATE()
      , Status = CASE WHEN  @c_IgnorCancOrd = 'Y' THEN Status ELSE @c_StatusCANC END  -- @c_OrderStatus  --NJOW05
      , SOStatus = CASE WHEN  @c_IgnorCancOrd = 'Y' THEN SOStatus ELSE @c_StatusCANC END  -- @c_SOStatus   --NJOW05
      , UserDefine04 = CASE WHEN @c_SC_SValue2 = '0' THEN ''
                        ELSE UserDefine04 END
      , TrackingNo = CASE WHEN @c_SC_SValue2 = '0' THEN ''
      ELSE TrackingNo END
   WHERE Orderkey = @c_Orderkey
      AND Status <> @c_StatusCANC
   SET @n_Err = @@ERROR
   IF @n_Err <> 0
   BEGIN
      ROLLBACK TRAN
      SET @n_Err = 80134
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                     + ': Update ORDERS Fail. '
                     + '. (isp_BackendCancelOrders)'
      GOTO PROCESS_END
   END
   COMMIT TRAN

   /* Update Order Detail (Start)               */
   /*********************************************/
/*  -- c_UpdOrdDetField from ws pass in
   IF @c_UpdOrdDetField <> ''
   BEGIN
      SET @c_ColumnName1 = ''
      SET @c_ColumnValue1 = ''
      SET @c_ExecStatements1 = ''

      SET @c_ColumnName1 = SUBSTRING(@c_UpdOrdDetField, 1, (CHARINDEX(':', @c_UpdOrdDetField) - 1))
      SET @c_ColumnValue1 = SUBSTRING(@c_UpdOrdDetField, (CHARINDEX(':', @c_UpdOrdDetField) + 1),
                           (LEN(@c_UpdOrdDetField) - CHARINDEX(':', @c_UpdOrdDetField)))
      IF @b_debug = 1
      BEGIN
         PRINT ' @c_ColumnName1=' + @c_ColumnName1
         PRINT '  @c_ColumnValue1=' + @c_ColumnValue1
      END
      SET @c_ExecStatements1 = @c_ColumnName1 + ' = ' +  QUOTENAME(@c_ColumnValue1, '''')
      IF @c_ExecStatements1 <> ''
      BEGIN
*/



   /* Delete Child Order (Start)                */
   CANCEL_CHILD_ORD: --(KH04)
/*
   IF @c_OrderGroup = 'CHILD_ORD'
   BEGIN

      UPDATE ORDERS WITH (ROWLOCK)
      SET EditWho = SUSER_NAME()
         , EditDate = GETDATE()
         , Status = @c_StatusCANC
         , SOStatus = @c_StatusCANC
         , UserDefine04 = CASE WHEN @c_SC_SValue2 = '0' THEN ''
            ELSE UserDefine04 END
         , TrackingNo = CASE WHEN @c_SC_SValue2 = '0' THEN ''
            ELSE TrackingNo END
         , OrderGroup = ''
      WHERE Orderkey = @c_ChildOrderKey

   END --IF @c_OrderGroup = 'CHILD_ORD'

   /* Release Child Order (Start)               */
*/
   IF @c_OrderGroup = 'CHILD_ORD' AND @n_AllowCancelCombineOrd = 1
   BEGIN

      BEGIN TRAN
      UPDATE ORDERS WITH (ROWLOCK)
      SET EditWho = SUSER_NAME()
         , EditDate = GETDATE()
         , Status = CASE WHEN  @c_IgnorCancOrd = 'Y' THEN Status ELSE @c_StatusCANC END  --NJOW05
         , SOStatus = CASE WHEN  @c_IgnorCancOrd = 'Y' THEN SOStatus ELSE @c_StatusCANC END --NJOW05
         , UserDefine04 = CASE WHEN @c_SC_SValue2 = '0' THEN ''
            ELSE UserDefine04 END
         , TrackingNo = CASE WHEN @c_SC_SValue2 = '0' THEN ''
            ELSE TrackingNo END
         , OrderGroup = ''
      WHERE Orderkey = @c_ChildOrderKey


      SET @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         ROLLBACK TRAN
         SET @n_Err = 80135
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                        + ': Update Orders Fail for Order OrderKey=' + @c_DB_ChildOrderKey
                        + '. (isp_BackendCancelOrders)'
       GOTO PROCESS_END
      END

      COMMIT TRAN

      -- SET @c_SOStatus = '0' --(KH04)
      SET @c_Prev_ChildOrderKey = ''
      DECLARE C_ChildOrdLoop CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT ISNULL(RTRIM(OrderKey), '')
            ,ISNULL(RTRIM(OrderLineNumber), '')
      FROM  ORDERDETAIL WITH (NOLOCK)
      WHERE ConsoOrderKey = @c_ConsoOrderKey
      AND ConsoOrderKey <> ''
      AND StorerKey = @c_StorerKey
      AND Status <> @c_StatusCANC
      ORDER BY ISNULL(RTRIM(OrderKey), ''), ISNULL(RTRIM(OrderLineNumber), '')

      OPEN C_ChildOrdLoop
      FETCH NEXT FROM C_ChildOrdLoop INTO @c_DB_ChildOrderKey, @c_DB_ChildOrderLineNumber
      WHILE @@FETCH_STATUS <> -1
      BEGIN

         IF @c_Prev_ChildOrderKey <> @c_DB_ChildOrderKey
         BEGIN
            SET @c_Prev_ChildOrderKey = @c_DB_ChildOrderKey

            IF   exists ( SELECT top 1 1
                  FROM  ORDERS WITH (NOLOCK)
                  WHERE Orderkey = @c_DB_ChildOrderKey AND StorerKey = @c_StorerKey
                  AND (SOStatus = 'PENDCANC' OR Status = @c_StatusCANC ) )
            BEGIN
               GOTO NEXT_CHILD_ORD
            END

            BEGIN TRAN

            UPDATE  ORDERS WITH (ROWLOCK)
            SET EditWho = SUSER_NAME()
               , EditDate = GETDATE()
               , OrderGroup = ''
               , SOStatus = '0'  --release
               , TrafficCop = NULL
               , Issued = 'Y'
               , UserDefine04 = ''
            WHERE Orderkey = @c_DB_ChildOrderKey
            AND StorerKey = @c_StorerKey
            AND SOStatus <> 'PENDCANC'
            AND Status <> @c_StatusCANC
            SET @n_Err = @@ERROR
            IF @n_Err <> 0
            BEGIN
               ROLLBACK TRAN
               SET @n_Err = 80136
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                              + ': Update Orders Fail for Child Order OrderKey=' + @c_DB_ChildOrderKey
                              + '. (isp_BackendCancelOrders)'
               GOTO PROCESS_END
            END

            COMMIT TRAN
         END --IF @c_Prev_ChildOrderKey <> @c_DB_ChildOrderKey

         BEGIN TRAN
         UPDATE  ORDERDETAIL WITH (ROWLOCK)
         SET EditWho = SUSER_NAME()
               , EditDate = GETDATE()
               , [Status] = '0'
               , ConsoOrderKey = '' --NULL
               , ExternConsoOrderKey = '' --NULL
               , TrafficCop = NULL
         WHERE Orderkey = @c_DB_ChildOrderKey
         AND OrderLineNumber = @c_DB_ChildOrderLineNumber
         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            ROLLBACK TRAN
            SET @n_Err = 80137
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                           + ': Update Order Detail Fail for Child Order OrderKey=' + @c_DB_ChildOrderKey
                           + '. (isp_BackendCancelOrders)'
        GOTO PROCESS_END
         END

         COMMIT TRAN

         NEXT_CHILD_ORD: --(KH04)

         FETCH NEXT FROM C_ChildOrdLoop INTO @c_DB_ChildOrderKey, @c_DB_ChildOrderLineNumber
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE C_ChildOrdLoop
      DEALLOCATE C_ChildOrdLoop
   END --IF @c_OrderGroup = 'CHILD_ORD'


   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END
   /*********************************************/
   /* Update Order Status (End)                 */
   /*********************************************/

   PROCESS_END:

   IF CURSOR_STATUS('GLOBAL' , 'C_PickingInfo_Delete') in (0 , 1)
   BEGIN
      CLOSE C_PickingInfo_Delete
      DEALLOCATE C_PickingInfo_Delete
   END

   IF CURSOR_STATUS('GLOBAL' , 'C_PickDetail_Delete') in (0 , 1)
   BEGIN
      CLOSE C_PickDetail_Delete
      DEALLOCATE C_PickDetail_Delete
   END

   IF CURSOR_STATUS('GLOBAL' , 'C_PickHeader_Delete') in (0 , 1)
   BEGIN
      CLOSE C_PickHeader_Delete
      DEALLOCATE C_PickHeader_Delete
   END

   IF CURSOR_STATUS('GLOBAL' , 'C_PackInfo_Delete') in (0 , 1)
   BEGIN
      CLOSE C_PackInfo_Delete
      DEALLOCATE C_PackInfo_Delete
   END

   IF CURSOR_STATUS('GLOBAL' , 'C_PackHeader_Delete') in (0 , 1)
   BEGIN
      CLOSE C_PackHeader_Delete
      DEALLOCATE C_PackHeader_Delete
   END

   IF CURSOR_STATUS('GLOBAL' , 'C_PackDetail_Delete') in (0 , 1)
   BEGIN
      CLOSE C_PackDetail_Delete
      DEALLOCATE C_PackDetail_Delete
   END

   IF CURSOR_STATUS('GLOBAL' , 'C_LoadPlanDetail_Delete') in (0 , 1)
   BEGIN
      CLOSE C_LoadPlanDetail_Delete
      DEALLOCATE C_LoadPlanDetail_Delete
   END

  IF CURSOR_STATUS('GLOBAL' , 'C_CartonTrackList_Delete') in (0 , 1)
   BEGIN
      CLOSE C_CartonTrackList_Delete
      DEALLOCATE C_CartonTrackList_Delete
   END

   IF CURSOR_STATUS('GLOBAL' , 'C_PreAllocatePickDetail_Delete') in (0 , 1)
   BEGIN
      CLOSE C_PreAllocatePickDetail_Delete
      DEALLOCATE C_PreAllocatePickDetail_Delete
   END

   --(KH03)
   IF CURSOR_STATUS('GLOBAL' , 'C_OrdDetUpdLoop') in (0 , 1)
   BEGIN
      CLOSE C_OrdDetUpdLoop
      DEALLOCATE C_OrdDetUpdLoop
   END

   --(KT01) - Start
   IF OBJECT_ID('tempdb..#TempMoveRecord') IS NOT NULL
   BEGIN
      DROP TABLE #TempMoveRecord
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN

   /* #INCLUDE <SPTPA01_2.SQL> */
   IF @n_Continue=3  -- Error Occured
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT > @n_StartTCnt
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

END

GO