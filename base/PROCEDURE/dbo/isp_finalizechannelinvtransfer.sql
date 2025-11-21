SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_FinalizeChannelInvTransfer                          */
/* Creation Date: 26-APR-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: Channel Inventory Transfer                                  */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 11-FEB-2019 LZG      1.1   INC0567559 - Fix new line inserted into   */
/*                            ChannelInv during finalization (ZG01)     */
/* 23-JUL-2019 Wan01    1.2   ChannelInventoryMgmt use nspGetRight2     */
/* 23-JUL-2019 Wan02    1.2.1 WMS - 9914 [MY] JDSPORTSMY - Channel      */
/*                            Inventory Ignore QtyOnHold - CR           */
/************************************************************************/
CREATE PROC [dbo].[isp_FinalizeChannelInvTransfer]
      @c_Facility          NVARCHAR(5)
   ,  @c_Storerkey         NVARCHAR(15)
   ,  @n_Channel_id        BIGINT
   ,  @c_ToChannel         NVARCHAR(20)
   ,  @n_ToQty             INT
   ,  @n_ToQtyOnHold       INT
   ,  @c_CustomerRef       NVARCHAR(30)
   ,  @c_Reasoncode        NVARCHAR(30)
   ,  @b_Success           INT            OUTPUT
   ,  @n_Err               INT            OUTPUT
   ,  @c_ErrMsg            NVARCHAR(255)  OUTPUT
   ,  @c_SourceKey         NVARCHAR(20) = ''
   ,  @c_SourceType        NVARCHAR(60) = 'isp_FinalizeChannelInvTransfer'
   ,  @c_ToFacility        NVARCHAR(20) = ''
   ,  @c_ToStorerkey       NVARCHAR(20) = ''
   ,  @c_ToSku             NVARCHAR(20) = ''
   ,  @c_ToC_Attribute01   NVARCHAR(30) = ''
   ,  @c_ToC_Attribute02   NVARCHAR(30) = ''
   ,  @c_ToC_Attribute03   NVARCHAR(30) = ''
   ,  @c_ToC_Attribute04   NVARCHAR(30) = ''
   ,  @c_ToC_Attribute05   NVARCHAR(30) = ''
   ,  @n_ToChannel_ID      BIGINT = 0  OUTPUT

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
           @n_StartTCnt       INT
         , @n_Continue        INT

         , @n_QtyAvailable    INT
         , @n_QtyOnHold       INT
         , @c_Channel         NVARCHAR(20)
         , @c_Sku             NVARCHAR(20)
         , @c_C_Attribute01   NVARCHAR(30)
         , @c_C_Attribute02   NVARCHAR(30)
         , @c_C_Attribute03   NVARCHAR(30)
         , @c_C_Attribute04   NVARCHAR(30)
         , @c_C_Attribute05   NVARCHAR(30)

         --, @n_ToChannel_ID       BIGINT
         , @c_ChannelTranRefNo   NVARCHAR(20)
         , @c_ChannelInvMgmt     NVARCHAR(10)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   IF @c_SourceType = 'isp_FinalizeChannelInvTransfer'
   BEGIN
      SET @c_ToFacility = @c_Facility
      SET @c_ToStorerKey= @c_StorerKey
   END

   SET @c_ChannelInvMgmt = '0'
   SET @b_success = 0
   Execute nspGetRight2       --(Wan01)
      @c_ToFacility
   ,  @c_ToStorerKey            -- Storer
   ,  ''                      -- Sku
   ,  'ChannelInventoryMgmt'  -- ConfigKey
   ,  @b_success              OUTPUT
   ,  @c_ChannelInvMgmt       OUTPUT
   ,  @n_err                  OUTPUT
   ,  @c_ErrMsg               OUTPUT

   IF @b_success <> 1
   BEGIN
      SET @n_continue = 3
      SET @n_err = 62010
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing nspGetRight'
                    + '. (isp_FinalizeChannelInvTransfer) ' + ISNULL(RTRIM(@c_ErrMsg),'')
      GOTO QUIT_SP
   END

   IF @c_ChannelInvMgmt = 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 62020
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Facilty: ' + RTRIM(@c_ToFacility)
                    + ' AND Storer: ' + RTRIM(@c_ToStorerkey) + ' does not setup Channel Inventory.'
                    + '. (isp_FinalizeChannelInvTransfer) ' + ISNULL(RTRIM(@c_ErrMsg),'')

      GOTO QUIT_SP
   END

   IF ISNULL(RTRIM(@c_ToChannel),'') = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62010
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': To Channel is required'
                      + '. (isp_FinalizeChannelInvTransfer)'
      GOTO QUIT_SP
   END

   IF @n_ToQty IS NULL AND @n_ToQtyOnHold IS NULL
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62020
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Either To Qty and To Qty ON Hold is required'
                      + '. (isp_FinalizeChannelInvTransfer)'
      GOTO QUIT_SP
   END

   SET @n_ToQty = ISNULL(@n_ToQty,0)
   SET @n_ToQtyOnHold = ISNULL(@n_ToQtyOnHold,0)

   IF ISNULL(RTRIM(@c_Reasoncode),'') = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62030
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Reason Code is required'
                      + '. (isp_FinalizeChannelInvTransfer)'
      GOTO QUIT_SP
   END

   SET @n_QtyAvailable = 0
   SET @n_QtyOnHold    = 0
   SET @c_Channel      = ''
   SET @c_C_Attribute01= ''
   SET @c_C_Attribute02= ''
   SET @c_C_Attribute03= ''
   SET @c_C_Attribute04= ''
   SET @c_C_Attribute05= ''

   SELECT @n_QtyAvailable = CI.Qty - CI.QtyAllocated - CI.QtyOnHold
         ,@n_QtyOnHold    = CI.QtyOnHold
         ,@c_Channel      = CI.Channel
         ,@c_Sku          = CI.Sku
         ,@c_C_Attribute01= CI.C_Attribute01
         ,@c_C_Attribute02= CI.C_Attribute02
         ,@c_C_Attribute03= CI.C_Attribute03
         ,@c_C_Attribute04= CI.C_Attribute04
         ,@c_C_Attribute05= CI.C_Attribute05
   FROM CHANNELINV CI WITH (NOLOCK)
   WHERE CI.Channel_ID = @n_Channel_ID

   IF ISNULL(RTRIM(@c_ToChannel),'') = @c_Channel
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62040
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Transfer Same Channel is not allowed'
                      + '. (isp_FinalizeChannelInvTransfer)'
      GOTO QUIT_SP
   END

   IF @n_ToQty > @n_QtyAvailable
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62050
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Disallow to transfer Qty > Qty Available'
                      + '. (isp_FinalizeChannelInvTransfer)'
      GOTO QUIT_SP
   END

   --(Wan02) - START
   IF @n_ToQtyOnHold > 0 
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62062
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Use Channel Inventory Hold function to hold channel qty.' 
                      + '. (isp_FinalizeChannelInvTransfer)'
      GOTO QUIT_SP
   END
   --(Wan02) - END

   IF @n_ToQtyOnHold > @n_QtyOnhold
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62060
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Invalid Transfer To Qty on hold. It is more than channel qty on hold'
                      + '. (isp_FinalizeChannelInvTransfer)'
      GOTO QUIT_SP
   END

   IF @c_SourceType = 'isp_FinalizeChannelInvTransfer'
   BEGIN
      SET @c_ToSku = @c_Sku
      SET @c_ToC_Attribute01 = @c_C_Attribute01
      SET @c_ToC_Attribute02 = @c_C_Attribute02
      SET @c_ToC_Attribute03 = @c_C_Attribute03
      SET @c_ToC_Attribute04 = @c_C_Attribute04
      SET @c_ToC_Attribute05 = @c_C_Attribute05
   END

   SET @n_ToChannel_ID = 0
   SELECT @n_ToChannel_ID = ci.Channel_ID
   FROM CHANNELINV AS ci WITH(NOLOCK)
   WHERE ci.StorerKey = @c_StorerKey
   AND   ci.SKU = @c_ToSku
   AND   ci.Facility = @c_ToFacility    -- ZG01
   AND   ci.Channel = @c_ToChannel
   AND   ci.C_Attribute01 = @c_ToC_Attribute01
   AND   ci.C_Attribute02 = @c_ToC_Attribute02
   AND   ci.C_Attribute03 = @c_ToC_Attribute03
   AND   ci.C_Attribute04 = @c_ToC_Attribute04
   AND   ci.C_Attribute05 = @c_ToC_Attribute05

   BEGIN TRAN

   SET @c_ChannelTranRefNo = ISNULL(RTRIM(@c_SourceKey),'')
   IF @c_SourceType = 'isp_FinalizeChannelInvTransfer'
   BEGIN
      SET @c_ChannelTranRefNo = ''
      EXECUTE nspg_GetKey
              @KeyName     = 'ChannelTranRefNo'
            , @fieldlength = 10
            , @keystring   = @c_ChannelTranRefNo   OUTPUT
            , @b_success   = @b_success            OUTPUT
            , @n_err       = @n_err                OUTPUT
            , @c_errmsg    = @c_errmsg             OUTPUT
            , @b_resultset = 0
            , @n_batch     = 0
   END

   IF @b_success <> 1
   BEGIN
      SET @n_continue = 3
      SET @n_err = 60000
      SET @c_errmsg='NSQL'+ CONVERT(CHAR(5),@n_err)+': Error Executing nspg_GetKey. (isp_Ecom_PackConfirm)'
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ).'

      GOTO QUIT_SP
   END


   IF @n_ToChannel_ID = 0
   BEGIN
      INSERT INTO CHANNELINV
               (
               StorerKey,           SKU,                 Facility,
               Channel,             C_Attribute01,       C_Attribute02,
               C_Attribute03,       C_Attribute04,       C_Attribute05,
               Qty,                 QtyAllocated,        QtyOnHold
               )
      VALUES   (
               @c_ToStorerKey,      @c_ToSKU,            @c_ToFacility,
               @c_ToChannel,        @c_ToC_Attribute01,  @c_ToC_Attribute02,
               @c_ToC_Attribute03,  @c_ToC_Attribute04,  @c_ToC_Attribute05,
               @n_ToQty + @n_ToQtyOnHold,      0,        @n_ToQtyOnHold
               )

      SET @n_Err = @@ERROR
      SET @n_ToChannel_ID = @@IDENTITY
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err      = 62070
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Insert Into CHANNELINV fail'
                         + '. (isp_FinalizeChannelInvTransfer)'
         GOTO QUIT_SP
      END
   END
   ELSE
   BEGIN
      UPDATE CHANNELINV WITH (ROWLOCK)
         SET Qty = Qty + @n_ToQty + @n_ToQtyOnHold
            ,QtyOnHold = QtyOnHold + @n_ToQtyOnHold
            ,EditWho  = SUSER_NAME()
            ,EditDate = GETDATE()
      WHERE Channel_ID = @n_ToChannel_ID

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err      = 62080
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Deposit Qty Into CHANNELINV fail'
                         + '. (isp_FinalizeChannelInvTransfer)'
         GOTO QUIT_SP
      END
   END

   INSERT INTO CHANNELITRAN
            (
            TranType,         ChannelTranRefNo,    SourceType,
            StorerKey,        SKU,                 Facility,
            Channel_ID,       Channel,
            C_Attribute01,    C_Attribute02,       C_Attribute03,
            C_Attribute04,    C_Attribute05,
            Qty,              QtyOnHold,
            Reasoncode,       CustomerRef
            )
   VALUES   (
            'WD',             @c_ChannelTranRefNo, @c_SourceType,
            @c_StorerKey,     @c_SKU,              @c_Facility,
            @n_Channel_ID,    @c_Channel,
            @c_C_Attribute01, @c_C_Attribute02,    @c_C_Attribute03,
            @c_C_Attribute04, @c_C_Attribute05,
            @n_ToQty        , @n_ToQtyOnHold,
            @c_Reasoncode,    @c_CustomerRef
            )

   IF @@ERROR <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62090
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Insert Into CHANNELITRAN fail'
                        + '. (isp_FinalizeChannelInvTransfer)'
      GOTO QUIT_SP
   END

   UPDATE CHANNELINV WITH (ROWLOCK)
      SET Qty = Qty - @n_ToQty - @n_ToQtyOnHold
         ,QtyOnHold = QtyOnHold - @n_ToQtyOnHold
         ,EditWho  = SUSER_NAME()
         ,EditDate = GETDATE()
   WHERE Channel_ID = @n_Channel_ID

   IF @@ERROR <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62100
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Withdraw Qty From CHANNELINV fail'
                        + '. (isp_FinalizeChannelInvTransfer)'
      GOTO QUIT_SP
   END

   INSERT INTO CHANNELITRAN
            (
            TranType,            ChannelTranRefNo,    SourceType,
            StorerKey,           SKU,                 Facility,
            Channel_ID,          Channel,
            C_Attribute01,       C_Attribute02,       C_Attribute03,
            C_Attribute04,       C_Attribute05,
            Qty,                 QtyOnHold,
            Reasoncode,          CustomerRef
            )
   VALUES   (
            'DP',                @c_ChannelTranRefNo, @c_SourceType,
            @c_ToStorerKey,      @c_ToSKU,            @c_ToFacility,    -- ZG01
            @n_ToChannel_ID,     @c_ToChannel,
            @c_ToC_Attribute01,  @c_ToC_Attribute02,  @c_ToC_Attribute03,
            @c_ToC_Attribute04,  @c_ToC_Attribute05,
            @n_ToQty        ,    @n_ToQtyOnHold,
            @c_Reasoncode,       @c_CustomerRef
            )

   IF @@ERROR <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 62110
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Insert Into CHANNELITRAN fail'
                        + '. (isp_FinalizeChannelInvTransfer)'
      GOTO QUIT_SP
   END

QUIT_SP:
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_FinalizeChannelInvTransfer'
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