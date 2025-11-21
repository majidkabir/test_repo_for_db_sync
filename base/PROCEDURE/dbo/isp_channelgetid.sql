SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_ChannelGetID                                   */
/* Creation Date:                                                       */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    ver   Purposes                                */
/* 09-Jul-2019  Leong     1.1   INC0769944 - Revise ErrMsg.             */
/************************************************************************/

CREATE PROC [dbo].[isp_ChannelGetID] (
    @c_StorerKey            NVARCHAR(15)
   ,@c_Sku                  NVARCHAR(20)
   ,@c_Facility             NVARCHAR(10)
   ,@c_Channel              NVARCHAR(30)
   ,@c_LOT                  NVARCHAR(10)
   ,@n_Channel_ID           BIGINT OUTPUT
   ,@b_Success              BIT = 1 OUTPUT
   ,@n_ErrNo                INT = 0 OUTPUT
   ,@c_ErrMsg               NVARCHAR(250) = '' OUTPUT
   ,@b_Debug                BIT = 0
   ,@c_CreateIfNotExist     NVARCHAR(10) = 'Y'
) AS
BEGIN
   SET NOCOUNT ON

   DECLARE @c_Channel_LTB          NVARCHAR(20)
          ,@c_C_AttributeLbl01     NVARCHAR(30)=''
          ,@c_C_AttributeLbl02     NVARCHAR(30)=''
          ,@c_C_AttributeLbl03     NVARCHAR(30)=''
          ,@c_C_AttributeLbl04     NVARCHAR(30)=''
          ,@c_C_AttributeLbl05     NVARCHAR(30)=''
          ,@c_C_Attribute01        NVARCHAR(30)=''
          ,@c_C_Attribute02        NVARCHAR(30)=''
          ,@c_C_Attribute03        NVARCHAR(30)=''
          ,@c_C_Attribute04        NVARCHAR(30)=''
          ,@c_C_Attribute05        NVARCHAR(30)=''
          ,@n_Qty                  INT
          ,@n_QtyAllocated         INT
          ,@c_SQL                  NVARCHAR(MAX)
          ,@n_Continue             INT = 1

   SET @n_Continue = 1

   IF ISNULL(@c_CreateIfNotExist,'') = ''
      SET @c_CreateIfNotExist = 'Y'

   IF ISNULL(RTRIM(@c_LOT),'') = ''
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_ErrNo = 50051 -- INC0769944
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_ErrNo) +
                         ': StorerKey= ' + ISNULL(RTRIM(@c_StorerKey),'') +
                         ', Sku= ' + ISNULL(RTRIM(@c_Sku),'') +
                         ', Facility= ' + ISNULL(RTRIM(@c_Facility),'') +
                         ', Channel= ' + ISNULL(RTRIM(@c_Channel),'') +
                         ', Lot= ' + ISNULL(RTRIM(@c_Lot),'') +
                         ': LOT Cannot be BLANK (isp_ChannelGetID)'
      GOTO EXIT_SP
   END

   SELECT @c_C_AttributeLbl01 = cac.C_AttributeLabel01
         ,@c_C_AttributeLbl02 = cac.C_AttributeLabel02
         ,@c_C_AttributeLbl03 = cac.C_AttributeLabel03
         ,@c_C_AttributeLbl04 = cac.C_AttributeLabel04
         ,@c_C_AttributeLbl05 = cac.C_AttributeLabel05
   FROM   ChannelAttributeConfig AS cac WITH(NOLOCK)
   WHERE  cac.StorerKey = @c_StorerKey
   IF @@ROWCOUNT = 0
   BEGIN
      SELECT @n_continue = 3
    SELECT @n_ErrNo = 50052 -- INC0769944
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_ErrNo) +
                         ': StorerKey= ' + ISNULL(RTRIM(@c_StorerKey),'') +
                         ', Sku= ' + ISNULL(RTRIM(@c_Sku),'') +
                         ', Facility= ' + ISNULL(RTRIM(@c_Facility),'') +
                         ', Channel= ' + ISNULL(RTRIM(@c_Channel),'') +
                         ', Lot= ' + ISNULL(RTRIM(@c_Lot),'') +
                         ': Channel Attribute Configuration Not Found! (isp_ChannelGetID)'
      GOTO EXIT_SP
   END

   SELECT @c_SQL =
          N'SELECT TOP 1 @c_C_Attribute01 = ' +
          CASE
               WHEN ISNULL(RTRIM(@c_C_AttributeLbl01) ,'')<>'' THEN 'LA.'+@c_C_AttributeLbl01
               ELSE ''''''
          END + ', @c_C_Attribute02 = ' +
          CASE
               WHEN ISNULL(RTRIM(@c_C_AttributeLbl02) ,'')<>'' THEN 'LA.'+@c_C_AttributeLbl02
               ELSE ''''''
          END + ', @c_C_Attribute03 = ' +
          CASE
               WHEN ISNULL(RTRIM(@c_C_AttributeLbl03) ,'')<>'' THEN 'LA.'+@c_C_AttributeLbl03
               ELSE ''''''
          END + ', @c_C_Attribute04 = ' +
          CASE
               WHEN ISNULL(RTRIM(@c_C_AttributeLbl04) ,'')<>'' THEN 'LA.'+@c_C_AttributeLbl04
               ELSE ''''''
          END + ',  @c_C_Attribute05 = ' +
          CASE
               WHEN ISNULL(RTRIM(@c_C_AttributeLbl05) ,'')<>'' THEN 'LA.'+@c_C_AttributeLbl05
               ELSE ''''''
          END + '
    FROM LOTATTRIBUTE AS LA WITH (NOLOCK)
    WHERE  LA.LOT = @c_LOT '

   IF @b_Debug = 1
      PRINT @c_SQL

   BEGIN TRY
      EXEC sp_ExecuteSQL @c_SQL,
      N' @c_LOT                  NVARCHAR(10)
        ,@c_C_Attribute01        NVARCHAR(30) OUTPUT
        ,@c_C_Attribute02        NVARCHAR(30) OUTPUT
        ,@c_C_Attribute03        NVARCHAR(30) OUTPUT
        ,@c_C_Attribute04        NVARCHAR(30) OUTPUT
        ,@c_C_Attribute05        NVARCHAR(30) OUTPUT',
       @c_LOT
      ,@c_C_Attribute01  OUTPUT
      ,@c_C_Attribute02  OUTPUT
      ,@c_C_Attribute03  OUTPUT
      ,@c_C_Attribute04  OUTPUT
      ,@c_C_Attribute05  OUTPUT
   END TRY

   BEGIN CATCH
      SET @b_Success = 0
      SET @n_Continue = 3
      SELECT @n_ErrNo  = ERROR_NUMBER(),
             @c_ErrMsg = ERROR_MESSAGE()
   END CATCH

   SET @c_C_Attribute01 = ISNULL(RTRIM(@c_C_Attribute01),'')
   SET @c_C_Attribute02 = ISNULL(RTRIM(@c_C_Attribute02),'')
   SET @c_C_Attribute03 = ISNULL(RTRIM(@c_C_Attribute03),'')
   SET @c_C_Attribute04 = ISNULL(RTRIM(@c_C_Attribute04),'')
   SET @c_C_Attribute05 = ISNULL(RTRIM(@c_C_Attribute05),'')

   SET @n_Channel_ID = 0
   SELECT @n_Channel_ID = ci.Channel_ID
   FROM ChannelInv AS ci WITH(NOLOCK)
   WHERE ci.StorerKey = @c_StorerKey
   AND   ci.SKU = @c_Sku
   AND   ci.Facility = @c_Facility
   AND   ci.Channel = @c_Channel
   AND   ci.C_Attribute01 = @c_C_Attribute01
   AND   ci.C_Attribute02 = @c_C_Attribute02
   AND   ci.C_Attribute03 = @c_C_Attribute03
   AND   ci.C_Attribute04 = @c_C_Attribute04
   AND   ci.C_Attribute05 = @c_C_Attribute05

   --IF @b_Debug = 1
   BEGIN
      --PRINT 'Channel_ID: ' + CAST(@n_Channel_ID AS VARCHAR(10))
      INSERT INTO TraceInfo
      (
         TraceName,
         TimeIn,
         [TimeOut],
         TotalTime,
         Step1,
         Step2,
         Step3,
         Step4,
         Step5,
         Col1,
         Col2,
         Col3,
         Col4,
         Col5
      )
      VALUES
      (
         'isp_ChannelGetID',
         GETDATE(),
         NULL,
         '',
         @c_StorerKey,
         @c_SKU,
         @c_Facility,
         @c_Channel,
         @c_LOT,
         @c_C_Attribute01,
         @c_C_Attribute02,
         @c_C_Attribute03,
         @c_C_Attribute04,
         @c_C_Attribute05
      )
   END

   IF @n_Channel_ID = 0 AND @c_CreateIfNotExist <> 'N'
   BEGIN
      INSERT INTO ChannelInv(
         StorerKey,     SKU,           Facility,
         Channel,       C_Attribute01, C_Attribute02,
         C_Attribute03, C_Attribute04, C_Attribute05,
         Qty,           QtyAllocated )
       VALUES(
         @c_StorerKey,     @c_SKU,           @c_Facility,
         @c_Channel,       @c_C_Attribute01, @c_C_Attribute02,
         @c_C_Attribute03, @c_C_Attribute04, @c_C_Attribute05,
         0,                0 )

      SET @n_Channel_ID = @@IDENTITY

   END

   EXIT_SP:
   IF @n_Continue = 3  -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_success = 0
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

      IF @n_IsRDT = 1
      BEGIN
         RAISERROR (@n_ErrNo, 10, 1) WITH SETERROR
      END
      ELSE
      BEGIN
         EXECUTE nsp_LogError @n_ErrNo, @c_ErrMsg, 'isp_ChannelGetID'
         RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR
         RETURN
      END
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      RETURN
   END
END -- Procedure

GO