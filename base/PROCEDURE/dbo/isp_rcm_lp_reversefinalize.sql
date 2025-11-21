SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_RCM_LP_ReverseFinalize                         */  
/* Creation Date: 02-Apr-2019                                           */  
/* Copyright: LF                                                        */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-8421-UA HK-New RCM option to Reverse Loadplan Finalized */  
/*                                                                      */  
/* Called By: Load Plan Dymaic RCM configure at listname 'RCMConfig'    */   
/*                                                                      */  
/* Parameters:                                                          */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_RCM_LP_ReverseFinalize]  
   @c_Loadkey NVARCHAR(10),     
   @b_success  int OUTPUT,  
   @n_err      int OUTPUT,  
   @c_errmsg   NVARCHAR(225) OUTPUT,  
   @c_code     NVARCHAR(30)=''  
AS  
BEGIN   
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_continue int,  
           @n_cnt int,  
           @n_starttcnt int  
             
   DECLARE @c_Facility     NVARCHAR(5),  
           @c_storerkey    NVARCHAR(15),
		   @c_finalizeFlag NVARCHAR(10),
		   @c_ORDShip      NVARCHAR(5),
		   @c_authority    NVARCHAR(5)   
                
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0 
   SET @c_finalizeFlag = ''
   SET @c_ORDShip = ''
   SET @c_authority = ''
     
     
   SELECT TOP 1 @c_Facility = Facility,  
                @c_Storerkey = Storerkey  
   FROM ORDERS (NOLOCK)  
   WHERE Loadkey = @c_Loadkey    
   
   IF NOT EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK) WHERE listname='LOADREVUSR' and storerkey=@c_Storerkey and code = SUSER_SNAME())
   BEGIN
      SET @c_authority = 'N'
	  SET @c_errmsg = 'User not had the right to run the scripts:'
   END

   IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE Loadkey = @c_Loadkey and storerkey = @c_Storerkey and status = '9')
   BEGIN
     SET @c_ORDShip = 'Y'
     SET @c_errmsg = @c_errmsg + ' Orders had been shipped:'
   END

   SELECT @c_finalizeFlag = LP.Finalizeflag
   FROM Loadplan LP WITH (NOLOCK) 
   WHERE LP.loadkey = @c_Loadkey

   IF @c_finalizeFlag <> 'Y'
   BEGIN
     SET @c_errmsg = @c_errmsg + ' Load had not been Finalize:'
   END 

   IF (@c_authority = 'N' OR @c_ORDShip = 'Y' OR @c_finalizeFlag <> 'Y') AND @c_errmsg <> ''
   BEGIN
    SELECT @n_continue = 3, @n_err = 60098, @c_errmsg = @c_errmsg +'(isp_RCM_LP_ReverseFinalize) ' 
   END
  
  IF @n_continue = 1
  BEGIN

  UPDATE LOADPLAN 
  SET Finalizeflag = 'N'
     ,Trafficcop = NULL 
  WHERE loadkey = @c_Loadkey

    IF @@ERROR <> 0
    BEGIN
     SELECT @n_continue = 3
     SELECT @n_err = 60099
	 SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0)) + ' Update Loadplan fail (isp_RCM_LP_ReverseFinalize)'
    END

  DELETE transmitlog3 
  WHERE key3= @c_Storerkey
  AND tablename='LOADORDLOG'
  AND key1 in (select orderkey FROM ORDERS (NOLOCK) WHERE Loadkey =@c_Loadkey)

   IF @@ERROR <> 0
    BEGIN
     SELECT @n_continue = 3
     SELECT @n_err = 60070
	 SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0)) + ' DELETE transmitlog3 fail (isp_RCM_LP_ReverseFinalize)'
    END
   END              
ENDPROC:   
   
  IF @n_continue=3  -- Error Occured - Process And Return  
  BEGIN  
     SELECT @b_success = 0  
     IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt  
     BEGIN  
        ROLLBACK TRAN  
     END  
  ELSE  
     BEGIN  
        WHILE @@TRANCOUNT > @n_starttcnt  
        BEGIN  
           COMMIT TRAN  
        END  
     END  
     execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_LP_ReverseFinalize'  
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
     RETURN  
  END  
  ELSE  
     BEGIN  
        SELECT @b_success = 1  
        WHILE @@TRANCOUNT > @n_starttcnt  
        BEGIN  
           COMMIT TRAN  
        END  
        RETURN  
     END      
END -- End PROC  
SET QUOTED_IDENTIFIER OFF 

GO