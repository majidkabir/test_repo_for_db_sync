SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_TCP_VC_prTaskLUTCoreSendVehicleIDs             */
/* Creation Date: 26-Feb-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/************************************************************************/
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTCoreSendVehicleIDs] (
    @c_TranDate     NVARCHAR(20)
   ,@c_DevSerialNo  NVARCHAR(20)
   ,@c_OperatorID   NVARCHAR(20)
   ,@c_VehicleType  NVARCHAR(20)
   ,@c_VehicleID    NVARCHAR(10)
   ,@n_SerialNo     INT
   ,@c_RtnMessage   NVARCHAR(500) = '' OUTPUT    
   ,@b_Success      INT = 1 OUTPUT
   ,@n_Error        INT = 0 OUTPUT
   ,@c_ErrMsg       NVARCHAR(255) = '' OUTPUT    
)
AS
BEGIN
   -- Return Message
   DECLARE @c_VehicleTypeDesc   NVARCHAR(100) -- A descriptive name for the vehicle type
         , @c_CaptureVehType    NVARCHAR(1)
         , @c_ErrorCode         NVARCHAR(20)
         , @c_Message           NVARCHAR(400)

   SET @c_ErrorCode = '0'
   SET @c_Message = ''
   SET @c_VehicleType = '2' 
   SET @c_VehicleTypeDesc = ''
   
   -- Determines if the VoiceApplication prompts the operator to specify a Vehicle ID for this vehicle type.
   -- 1 = Yes Else Other Value is 'No'
   SET @c_CaptureVehType = '2'
   
   SET @c_ErrorCode = 0 
   SET @c_Message = ''
   
   -- Not using now, send back dummy data
   SET @c_RtnMessage = ',0,'
   

   
END

GO