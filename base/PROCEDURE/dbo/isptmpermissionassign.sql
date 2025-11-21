SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispTMPermissionAssign                              */
/* Creation Date: 06-Oct-2011                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: 213265 - Task Manager Permission Profile                    */   
/*                                                                      */
/* Called By: Task Manager Permission Assign                            */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/

CREATE PROC [dbo].[ispTMPermissionAssign]   
   @cProfileKey NVARCHAR(10),  
   @cUserKey    NVARCHAR(18),
   @bSuccess    INT = 1  OUTPUT,
   @nErrNo      INT      OUTPUT, 
   @cErrMsg     NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @nContinue            INT,
           @nStartTCnt           INT,
           @cStrategyKey         NVARCHAR(10),
           @cEquipmentProfilekey NVARCHAR(10)

	 SELECT @nContinue=1, @nStartTCnt=@@TRANCOUNT
	
   IF NOT EXISTS(SELECT 1 FROM TMPermissionProfileDetail (NOLOCK) WHERE Profilekey = @cProfilekey)
   BEGIN
	    SELECT @nContinue=3
	    SELECT @nErrNo=32801
	    SELECT @cErrmsg='NSQL'+CONVERT(varchar(5),@nErrNo)+': No permission detail setup for profile ' + RTRIM(@cProfilekey)
   END 

	 IF @nContinue = 1 OR @nContinue = 2
	 BEGIN
	 	  DELETE FROM TASKMANAGERUSERDETAIL WHERE Userkey = @cUserkey

	 	  SELECT @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SELECT @nContinue = 3
         SELECT @cErrMsg = CONVERT(CHAR(250),@nErrNo), @nErrNo=32802  
         SELECT @cErrMsg="NSQL"+CONVERT(char(5),@nErrNo)+": Delete TaskManagerUserDetail Failed. (ispTMPermissionAssign)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@cErrMsg)) + " ) "
      END
	 END
	 
	 IF @nContinue = 1 OR @nContinue = 2
	 BEGIN
	 	  INSERT INTO TASKMANAGERUSERDETAIL (Userkey, UserLineNumber, PermissionType, AreaKey, Permission)
	 	  SELECT @cUserkey, TMPermissionProfileDetail.ProfileLineNumber, TMPermissionProfileDetail.PermissionType,
	 	         TMPermissionProfileDetail.AreaKey, TMPermissionProfileDetail.Permission
	 	  FROM TMPermissionProfileDetail (NOLOCK)
	 	  WHERE TMPermissionProfileDetail.ProfileKey = @cProfileKey 
	 	  
	 	  SELECT @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SELECT @nContinue = 3
         SELECT @cErrMsg = CONVERT(CHAR(250),@nErrNo), @nErrNo=32803  
         SELECT @cErrMsg="NSQL"+CONVERT(char(5),@nErrNo)+": Insert TaskManagerUserDetail Failed. (ispTMPermissionAssign)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@cErrMsg)) + " ) "
      END	 	  
	 END

	 IF @nContinue = 1 OR @nContinue = 2
	 BEGIN
	 	  SELECT @cStrategyKey = TMPermissionProfile.StrategyKey, 
	 	         @cEquipmentProfileKey = TMPermissionProfile.EquipmentProfileKey
	 	  FROM TMPermissionProfile (NOLOCK)
	 	  WHERE TMPermissionProfile.ProfileKey = @cProfileKey
	 	
	 	  UPDATE TASKMANAGERUSER WITH (ROWLOCK)
	 	  SET TASKMANAGERUSER.LastPermissionProfileKey = @cProfileKey,
	 	      TASKMANAGERUSER.StrategyKey = @cStrategyKey,
	 	      TASKMANAGERUSER.EquipmentProfileKey = @cEquipmentProfileKey,
	 	      TrafficCop = NULL
	 	  WHERE TASKMANAGERUSER.UserKey = @cUserKey
	 	  
	 	  SELECT @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SELECT @nContinue = 3
         SELECT @cErrMsg = CONVERT(CHAR(250),@nErrNo), @nErrNo=32804  
         SELECT @cErrMsg="NSQL"+CONVERT(char(5),@nErrNo)+": Update TaskManagerUser Failed. (ispTMPermissionAssign)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@cErrMsg)) + " ) "
      END	 	  
	 END
                  
	 IF @nContinue=3  -- Error Occured - Process AND Return
	 BEGIN
	    SELECT @bSuccess = 0
	 	 IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @nStartTCnt
	 	 BEGIN
	 	 	ROLLBACK TRAN
	 	 END
	 	 ELSE
	 	 BEGIN
	 	 	WHILE @@TRANCOUNT > @nStartTCnt
	 	 	BEGIN
	 	 		COMMIT TRAN
	 	 	END
	 	 END
	 	 EXECUTE dbo.nsp_LogError @nErrNo, @cErrmsg, 'ispTMPermissionAssign'		
	 	 RAISERROR (@cErrMsg, 16, 1) WITH SETERROR    -- SQL2012
	 	 RETURN
	 END
	 ELSE
	 BEGIN
	    SELECT @bSuccess = 1
	 	 WHILE @@TRANCOUNT > @nStartTCnt
	 	 BEGIN
	 	 	COMMIT TRAN
	 	 END
	 	 RETURN
	 END  
END  

GO