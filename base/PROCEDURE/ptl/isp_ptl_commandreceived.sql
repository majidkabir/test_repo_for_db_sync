SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Stored Procedure: isp_PTL_CommandReceived                                  */
/* Copyright: IDS                                                             */
/* Purpose: BondDPC Integration SP                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2013-03-02 1.0  Shong      Created                                         */
/* 2019-01-22 1.1  ChewKP     Performance Tuning                              */
/* 2020-04-21 1.2  Ung        INC1120103 Remove transaction                   */
/* 2024-07-30 1.3  yeekung    UWP-22410 Add new Column(yeekung05)					*/
/******************************************************************************/
CREATE   PROC [PTL].[isp_PTL_CommandReceived]
(  @c_DeviceIPAddress NVARCHAR(30)
  ,@c_DevicePosition  NVARCHAR(20)
  ,@c_FuncKey         NVARCHAR(2) -- 00 = NO, 10 = YES
  ,@c_InputValue      NVARCHAR(30)
  ,@n_LightLinkLogKey BIGINT OUTPUT
  ,@b_Success         INT OUTPUT
  ,@n_ErrNo           INT OUTPUT
  ,@c_ErrMsg          NVARCHAR(215) OUTPUT
  ,@c_Facility			 NVARCHAR(20)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Func            INT
          ,@n_Step            INT
          ,@c_DisplayValue    NVARCHAR(20)
          ,@c_PTLStatus       CHAR(1)
          ,@c_DeviceID        NVARCHAR(20)
          ,@n_Qty             INT
          ,@c_StoredProcName  NVARCHAR(1000)
          ,@c_StoredProcParm  NVARCHAR(1000)
          ,@c_UserName        NVARCHAR(20)
          ,@c_PTL_DisplayValue NVARCHAR(10)
          ,@n_LghIn_SerialNo   BIGINT
          ,@c_AlertLightMode   NVARCHAR(10)
          ,@c_StorerKey        NVARCHAR(15)
          ,@cDebug             NVARCHAR( 1) = 0

   SET @b_Success = 1
   SET @n_ErrNo   = 0
   SET @c_ErrMsg  = ''
   SET @n_LightLinkLogKey = 0

   BEGIN
      IF @c_FuncKey = '00' AND ISNULL(RTRIM(@c_InputValue), '') = ''
      BEGIN
         SELECT @c_InputValue = DisplayValue
         FROM PTL.LightStatus WITH (NOLOCK)
         WHERE IPAddress = @c_DeviceIPAddress
				AND DevicePosition = @c_DevicePosition
				AND Facility = @c_Facility
      END

      SET @n_LghIn_SerialNo = 0

      SELECT TOP 1
             @n_LghIn_SerialNo = li.SerialNo
      FROM PTL.LightInput AS li WITH (NOLOCK)
      WHERE li.IPAddress = @c_DeviceIPAddress
      AND   li.DevicePosition = @c_DevicePosition
      AND   li.[Status] = '0'
		AND   li.Facility = @c_Facility
      ORDER BY li.SerialNo

      IF ISNULL(@n_LghIn_SerialNo, 0) <> 0
      BEGIN
         UPDATE PTL.LightInput WITH (ROWLOCK)
            SET [Status] = '1'
              , EditDate = GETDATE()
              , InputData = @c_InputValue
         WHERE SerialNo = @n_LghIn_SerialNo
         AND   IPAddress = @c_DeviceIPAddress
         AND   DevicePosition = @c_DevicePosition
         AND   [Status] = '0'
			AND   Facility = @c_Facility
      END

      SELECT @n_Step = ls.Step,
             @c_DisplayValue = ls.DisplayValue,
             @c_PTLStatus = ls.[Status],
             @c_UserName   = ls.UserName,
             @n_Func = ls.Func,
             @c_StorerKey = ls.StorerKey
      FROM PTL.LightStatus AS ls WITH (NOLOCK)
      WHERE ls.IPAddress = @c_DeviceIPAddress
      AND   ls.DevicePosition = @c_DevicePosition
		AND	ls.Facility = @c_Facility

      SET @n_ErrNo = 0
      SET @c_StoredProcName = ''

      -- Get the stor proc to execute
      SET @c_StoredProcName = rdt.RDTGetConfig( @n_Func, 'PTLConfirmSP', @c_StorerKey)

      IF @c_StoredProcName = '0'
      BEGIN
         SET @c_StoredProcName = ''
      END

      -- Execute the stor proc
      IF ISNULL(RTRIM(@c_StoredProcName),'') <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_StoredProcName) AND type = 'P' )
         BEGIN
            SET @c_ErrMsg = 'SP Not Exist'
            SET @n_ErrNo  = 94101
            SET @b_Success = 0
            GOTO Quit
         END
         ELSE
         BEGIN
            SET @c_StoredProcName = N'EXEC PTL.' + RTRIM(@c_StoredProcName)
            SET @c_StoredProcName = RTRIM(@c_StoredProcName) +
                                    N' @c_DeviceIPAddress, @c_DevicePosition, @c_FuncKey, @n_LghIn_SerialNo, ' +
                                    N'@c_InputValue, @n_ErrNo OUTPUT, @c_ErrMsg OUTPUT,@cDebug,@c_Facility'
            SET @c_StoredProcParm = N'@c_DeviceIPAddress NVARCHAR(30), @c_DevicePosition  NVARCHAR(20), ' +
                                    N'@c_FuncKey NVARCHAR(2), @n_LghIn_SerialNo BIGINT, @c_InputValue NVARCHAR(30), ' +
                                    N'@n_ErrNo int OUTPUT,  @c_ErrMsg NVARCHAR(125) OUTPUT,@cDebug NVARCHAR( 1),@c_Facility NVARCHAR(20)'
            EXEC sp_executesql @c_StoredProcName,
               @c_StoredProcParm,
               @c_DeviceIPAddress,
               @c_DevicePosition,
               @c_FuncKey,
               @n_LghIn_SerialNo,
               @c_InputValue,
               @n_ErrNo OUTPUT,
               @c_ErrMsg OUTPUT,
               @cDebug,
               @c_Facility

            IF ISNULL(RTRIM(@c_ErrMsg),'') <> ''
            BEGIN
               UPDATE PTL.LightInput WITH (ROWLOCK)
                  SET [Status] = '5'
                     , EditDate = GETDATE()
                     , ErrorMessage = @c_ErrMsg
               WHERE IPAddress = @c_DeviceIPAddress
               AND   DevicePosition = @c_DevicePosition
               AND   [Status] = '1'
					AND   Facility = @c_Facility
            END
            ELSE
            BEGIN
               UPDATE PTL.LightInput WITH (ROWLOCK)
                  SET [Status] = '9', EditDate = GETDATE()
               WHERE SerialNo = @n_LghIn_SerialNo
            END
         END
      END
      ELSE
      BEGIN
         UPDATE PTL.LightInput WITH (ROWLOCK)
            SET [Status] = '9', EditDate = GETDATE()
         WHERE SerialNo = @n_LghIn_SerialNo
      END
   END

Quit:

END

GO