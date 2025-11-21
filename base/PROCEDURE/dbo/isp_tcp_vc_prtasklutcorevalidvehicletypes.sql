SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_TCP_VC_prTaskLUTCoreValidVehicleTypes          */
/* Creation Date: 26-Feb-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: This message retrieves all the valid break types that can be*/
/*          specified by the operator. If a host system does not want to*/
/*          support break types, the host should return a response in   */
/*          the format below, with all fields blank except Error Code,  */
/*          which should be set to 0.                                   */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/************************************************************************/
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTCoreValidVehicleTypes] (
    @c_TranDate     NVARCHAR(20)
   ,@c_DevSerialNo  NVARCHAR(20)
   ,@c_OperatorID   NVARCHAR(20)
   ,@n_VoiceAppID   INT
   ,@n_SerialNo     INT
   ,@c_RtnMessage   NVARCHAR(500) = '' OUTPUT    
   ,@b_Success      INT = 1 OUTPUT
   ,@n_Error        INT = 0 OUTPUT
   ,@c_ErrMsg       NVARCHAR(255) = '' OUTPUT    
)
AS
BEGIN
   -- Return Message
   DECLARE @c_VehicleType       NVARCHAR(5)   -- Vehicle type the operator can use.
         , @c_VehicleTypeDesc   NVARCHAR(100) -- A descriptive name for the vehicle type
         , @c_CaptureVehType    NVARCHAR(1)
         , @c_ErrorCode         NVARCHAR(20)
         , @c_Message           NVARCHAR(400)

   SET @c_ErrorCode = '0'
   SET @c_Message = ''
   SET @c_VehicleType = '' 
   SET @c_VehicleTypeDesc = ''
   
   -- Determines if the VoiceApplication prompts the operator to specify a Vehicle ID for this vehicle type.
   -- 1 = Yes Else Other Value is 'No'
   SET @c_CaptureVehType = '0'
   
   SET @c_ErrorCode = 0 
   SET @c_Message = ''
   
   SET @c_RtnMessage = @c_VehicleType + 
                       ',' + @c_VehicleTypeDesc + 
                       ',' + @c_CaptureVehType + 
                       ',' + @c_ErrorCode + 
                       ',' + @c_Message  
   
   
   
   
END

GO