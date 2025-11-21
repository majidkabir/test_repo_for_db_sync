SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_TCP_WCS_SORTATION_IN                           */
/* Creation Date: 08-11-2010                                            */
/* Copyright: IDS                                                       */
/* Written by: Chew KP                                                  */
/*                                                                      */
/* Purpose: Carton Sortation                                            */
/*          RedWerks to WMS Exceed                                      */
/*                                                                      */
/* Input Parameters:  @c_MessageNo    - Unique no for Incoming data     */
/*                                                                      */
/* Output Parameters: @b_Success       - Success Flag  = 0              */
/*                    @n_Err           - Error Code    = 0              */
/*                    @c_ErrMsg        - Error Message = ''             */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 14-03-2012   ChewKP    1.1   Update PackInfo.Weight (ChewKP01)       */
/* 07-04-2012   SHong     1.2   Trigger Agile Rate Request              */
/* 03-09-2012   Leong     1.3   SOS# 254851 - Standardize in progress   */
/*                                   update for table TCPSOCKET_INLOG   */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_TCP_WCS_SORTATION_IN]
     @c_MessageNum  NVARCHAR(10)
   , @b_Debug      INT
   , @b_Success    INT        OUTPUT
   , @n_Err        INT        OUTPUT
   , @c_ErrMsg     NVARCHAR(250)  OUTPUT

AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ExecStatements     NVARCHAR(4000)
         , @c_ExecArguments      NVARCHAR(4000)
         , @n_Continue           INT
         , @n_StartTCnt          INT

   DECLARE @n_SerialNo           INT
         , @c_Status             NVARCHAR(1)
         , @c_DataString         NVARCHAR(4000)
         , @c_MessageType        NVARCHAR(15)
         , @c_LaneNumber         NVARCHAR(10)
         , @c_SequenceNumber     NVARCHAR(10)
         , @c_LabelNo            NVARCHAR(20)
         , @f_Weight             FLOAT        -- (ChewKP01)
         , @c_Weight             NVARCHAR(10)  -- (ChewKP01)
         , @n_CartonNo           INT          -- (ChewKP01)
         , @c_PickSlipNo         NVARCHAR(10)  -- (ChewKP01)
         , @c_AgileProcess       NVARCHAR(1)
         , @c_OrderKey           NVARCHAR(10)
         , @c_LoadKey            NVARCHAR(10)
         , @c_ConsoOrderKey      NVARCHAR(30)
         , @c_Facility           NVARCHAR(5)
         , @c_StorerKey          NVARCHAR(15)

   SET @c_AgileProcess ='0'
   SELECT @n_Continue = 1, @b_success = 1, @n_Err = 0
   SET @n_StartTCnt = @@TRANCOUNT


   BEGIN TRAN
   SAVE TRAN WCS_SORTATION

   SET @c_ErrMsg           = ''
   SET @c_Status           = '9'
   SET @n_SerialNo         = 0
   SET @c_DataString       = ''
   SET @c_MessageType      = ''
   SET @c_LaneNumber       = ''
   SET @c_SequenceNumber   = ''
   SET @c_LabelNo          = ''
   SET @c_PickSlipNo       = ''
   SET @f_Weight           = 0   -- (ChewKP01)
   SET @c_Weight           = ''  -- (ChewKP01)
   SET @n_CartonNo         = 0   -- (ChewKP01)


   SELECT @n_SerialNo   = SerialNo
        , @c_DataString = ISNULL(RTRIM(DATA), '')
   FROM   dbo.TCPSocket_INLog WITH (NOLOCK)
   WHERE  MessageNum     = @c_MessageNum
   AND    MessageType   = 'RECEIVE'
   AND    Status        = '0'

   IF ISNULL(RTRIM(@n_SerialNo),'') = ''
   BEGIN
      IF @b_Debug = 1
      BEGIN
         SELECT 'Nothing to process. MessageNo = ' + @c_MessageNum
      END

      RETURN
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '@n_SerialNo : ' + CONVERT(VARCHAR, @n_SerialNo)
           + ', @c_Status : ' + @c_Status
           + ', @c_DataString : ' + @c_DataString
   END

   UPDATE dbo.TCPSOCKET_INLOG WITH (ROWLOCK) -- SOS# 254851
   SET Status = '1'
   WHERE SerialNo = @n_SerialNo

   IF ISNULL(RTRIM(@c_DataString),'') = ''
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Data String is empty. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_SORTATION_IN)'
      GOTO QUIT_SP
   END


   SELECT --@c_MessageNumber = MessageNum
          @c_MessageType = MessageType
         ,@c_LaneNumber = LaneNumber
         ,@c_SequenceNumber = SequenceNumber
         ,@c_LabelNo = GS1Label
         ,@c_Weight = Weight -- (ChewKP01)
   FROM dbo.fnc_GetTCPCartonSort( @n_SerialNo )

   IF @b_Debug = 1
   BEGIN
      SELECT --@c_MessageNumber = MessageNum
         @c_MessageType = MessageType
         ,@c_LaneNumber = LaneNumber
         ,@c_SequenceNumber = SequenceNumber
         ,@c_LabelNo = GS1Label
         ,@c_Weight = Weight -- (ChewKP01)
      FROM dbo.fnc_GetTCPCartonSort( @n_SerialNo )

   END

   IF ISNULL(RTRIM(@c_MessageType),'') <> 'CARTONSORT'
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_MessageNum) + ' Failed. Invalid MessageType ' + CONVERT(VARCHAR, @c_MessageType) + ' for process. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_SORTATION_IN)'
      GOTO QUIT_SP
   END


   IF ISNULL(RTRIM(@c_LabelNo),'') = ''
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_MessageType) + ' Failed. GSI Label is empty. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_SORTATION_IN)'
      GOTO QUIT_SP
   END

   IF NOT EXISTS ( SELECT 1 FROM dbo.PACKDETAIL WITH (NOLOCK)
                   WHERE LabelNo = @c_LabelNo)
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_MessageType) + ' Failed. Packing Not Done. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_SORTATION_IN)'
      GOTO QUIT_SP
   END

   IF EXISTS ( SELECT 1 FROM dbo.WCS_Sortation WITH (NOLOCK)
                   WHERE LabelNo = @c_LabelNo)
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_MessageType) + ' Failed. Label Exists. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_SORTATION_IN)'
      GOTO QUIT_SP
   END


   -- INSERT INTO WCS_SORTATION TABLE

   INSERT INTO dbo.WCS_SORTATION ( LP_LaneNumber, SeqNo, LabelNo)
   VALUES ( @c_LaneNumber, CAST(@c_SequenceNumber as INT), @c_LabelNo)

   SET @n_Err = @@ERROR

   IF @n_Err <> 0
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 12004
      SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Insert WCS_Sortation Table. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_SORTATION_IN)'
                       + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
      GOTO QUIT_SP
   END

    -- (ChewKP01)
   /***************************************************/
   /* Update PackInfo.Weight                          */
   /***************************************************/

   IF @c_Weight = ''
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_MessageType) + ' Failed. Weight is empty. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_SORTATION_IN)'
      GOTO QUIT_SP
   END

   SELECT TOP 1
          @c_PickSlipNo = PickSlipNo
         ,@n_CartonNo   = CartonNo
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE LabelNo = @c_LabelNo

   SET @f_Weight = CAST(@c_Weight AS FLOAT)
   IF @f_Weight > 0
   BEGIN
      -- Get OrderKey
      SELECT @c_OrderKey = ISNULL(ph.OrderKey,''),
             @c_LoadKey  = ISNULL(ph.LoadKey,''),
             @c_ConsoOrderKey = ISNULL(ph.ConsoOrderKey,'')
      FROM PackHeader ph (NOLOCK)
      WHERE ph.PickSlipNo = @c_PickSlipNo

      IF @c_OrderKey = '' AND @c_ConsoOrderKey <> ''
      BEGIN
         SELECT TOP 1
            @c_OrderKey  = od.OrderKey
         FROM ORDERDETAIL  od WITH (NOLOCK)
         WHERE od.ConsoOrderKey = @c_ConsoOrderKey
      END
      ELSE IF @c_OrderKey = '' AND @c_LoadKey <> ''
      BEGIN
         SELECT TOP 1
            @c_OrderKey =  lpd.OrderKey
         FROM LoadPlanDetail lpd (NOLOCK)
         WHERE lpd.LoadKey = @c_LoadKey
      END
      SELECT @c_Facility = Facility,
             @c_StorerKey = StorerKey
      FROM ORDERS WITH (NOLOCK)
      WHERE OrderKey = @c_OrderKey

      UPDATE dbo.PackInfo WITH (ROWLOCK)
         SET Weight = @f_Weight
      WHERE PickSlipNo = @c_PickSlipNo
      AND   CartonNo   = @n_CartonNo

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @c_Status = '5'
         SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 12004
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Update PackDetail Table. GS1#: ' + CONVERT(VARCHAR, @c_LabelNo) + '. (isp_TCP_WCS_SORTATION_IN)'
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
         GOTO QUIT_SP
      END

      EXEC dbo.nspGetRight
          @c_Facility,
          @c_StorerKey,
          NULL,
          'AgileProcess',
          @b_Success        OUTPUT,
          @c_AgileProcess   OUTPUT,
          @n_Err            OUTPUT,
          @c_ErrMsg         OUTPUT
      IF @c_AgileProcess = '1'
      BEGIN
        -- Send rate from Agile (carrier consolidation system)
         EXEC dbo.isp1156P_Agile_Rate
             @c_PickSlipNo
            ,@n_CartonNo
            ,@c_LabelNo
            ,@b_Success OUTPUT
            ,@n_Err     OUTPUT
            ,@c_ErrMsg  OUTPUT
         IF @n_Err <> 0 OR @b_Success <> 1
         BEGIN
            SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 12005
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': isp1156P_Agile_Rate Failed. GS1#: ' + CONVERT(VARCHAR, @c_LabelNo) + '. (isp_TCP_WCS_SORTATION_IN)'
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
         END
      END

   END

   /***************************************************/
   /* Interface with AGILE                            */
   /***************************************************/


   QUIT_SP:

   IF @b_Debug = 1
   BEGIN
      SELECT 'Update TCPSocket_INLog >> @c_Status : ' + @c_Status
           + ', @c_ErrMsg : ' + @c_ErrMsg
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      ROLLBACK TRAN WCS_SORTATION
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_TCP_WCS_SORTATION_IN'
   END

   UPDATE dbo.TCPSocket_INLog WITH (ROWLOCK)
   SET STATUS   = @c_Status
     , ErrMsg   = @c_ErrMsg
     , Editdate = GETDATE()
     , EditWho  = SUSER_SNAME()
   WHERE SerialNo = @n_SerialNo

   WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started
      COMMIT TRAN WCS_SORTATION

   RETURN
END

GO