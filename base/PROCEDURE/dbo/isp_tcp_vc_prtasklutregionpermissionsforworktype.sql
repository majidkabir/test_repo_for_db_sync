SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_TCP_VC_prTaskLUTRegionPermissionsForWorkType   */
/* Creation Date: 26-Feb-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purposes: The message returns the regions where the operator is      */
/*           allowed to perform the selection function.                 */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/************************************************************************/
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTRegionPermissionsForWorkType] (
    @c_TranDate     NVARCHAR(20)
   ,@c_DevSerialNo  NVARCHAR(20)
   ,@c_OperatorID   NVARCHAR(20)
   ,@c_SelWorkType  NVARCHAR(20) -- 3 = Normal Assignments, 4 = Chase Assignments, 6 = Normal and Chase Assignments
   ,@n_SerialNo     INT
   ,@c_RtnMessage   NVARCHAR(500) OUTPUT    
   ,@b_Success      INT = 1 OUTPUT
   ,@n_Error        INT = 0 OUTPUT
   ,@c_ErrMsg       NVARCHAR(255) = '' OUTPUT 

)
AS
BEGIN
   DECLARE @c_ErrorCode         NVARCHAR(20) --  0: No error. The VoiceApplication proceeds.
                                            -- 98: Critical error. If this error is received, 
                                            --     the VoiceApplication speaks the error message, and forces the operator to sign off. 
                                            -- 99: Informational error. The VoiceApplication speaks the informational error message, 
                                            --     but does not force the operator to sign off.
         , @c_Message           NVARCHAR(400)
         , @c_AreaKey           NVARCHAR(10)
         , @c_PermissionType    NVARCHAR(10)
         , @n_Options           INT 

   SET @c_RtnMessage = ''
   SET @n_Options = 0
   
   DECLARE CUR_AreaPermission CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT tmud.AreaKey, tmud.PermissionType
   FROM TaskManagerUserDetail tmud WITH (NOLOCK)
   WHERE tmud.UserKey = @c_OperatorID 
   AND tmud.Permission = '1' 
   AND tmud.PermissionType IN ('VNPK', 'VCPK')

   ORDER BY tmud.AreaKey 
   
   OPEN CUR_AreaPermission
   
   FETCH NEXT FROM CUR_AreaPermission INTO @c_AreaKey, @c_PermissionType 
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF ( ( @c_SelWorkType = '3' AND @c_PermissionType = 'VNPK') OR 
           ( @c_SelWorkType = '4' AND @c_PermissionType = 'VCPK') OR  
           ( @c_SelWorkType = '6') )
      BEGIN
         SET @n_Options = @n_Options + 1
         
         SET @c_RtnMessage = CASE WHEN LEN(@c_RtnMessage) = 0 THEN '' ELSE RTRIM(@c_RtnMessage) + '<CR><LF>' END + RTRIM(@c_AreaKey) + ',' + RTRIM(@c_AreaKey) + ',0,'   
      END
      
      FETCH NEXT FROM CUR_AreaPermission INTO @c_AreaKey, @c_PermissionType 
   END
   CLOSE CUR_AreaPermission
   DEALLOCATE CUR_AreaPermission
   
      
   SET @c_ErrorCode = 0 
   SET @c_Message = ''
   
   IF LEN(@c_RtnMessage) = 0 
   BEGIN
      SET @c_RtnMessage = '1,All Area,0,'
   END
   ELSE
   BEGIN
      SET @c_RtnMessage = @c_RtnMessage 
   END  
   
   
END

GO