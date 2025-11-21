SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_AutoDeployment                                 */
/* Creation Date: 28-Oct-2015                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Auto deployment for new PBD                                 */
/*                                                                      */
/* Called By: n_cst_appmanager_exceed.ue_autodbdeploment()              */ 
/*            custom deploy sp will be drop thru SQL job                */
/*            isp_DropAutoDeployed based on IDS_GENERALLOG record       */
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0	                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_AutoDeployment]
   @dt_exebuilddate DATETIME,
   @b_success  INT OUTPUT,
   @n_err      INT OUTPUT,
   @c_errmsg   NVARCHAR(225) OUTPUT
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,
           @n_cnt int,
           @n_starttcnt int,
           @c_spname nvarchar(30),
           @c_exespname nvarchar(30)
                               
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt = @@TRANCOUNT, @c_errmsg='', @n_err=0 

   SET @c_SPName = 'isp_Deploy_'+ CONVERT(NVARCHAR(10), @dt_exebuilddate, 112)

   DECLARE CUR_DEPLOYSP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT DISTINCT s.name 
       FROM dbo.sysobjects s
       LEFT JOIN IDS_GENERALLOG g (NOLOCK) ON g.UDF04 = 'AUTODEPLOYED' AND s.name = g.UDF01
       WHERE s.type = 'P' 
       AND s.name <= @c_SPName 
       AND LEFT(s.name,11) = 'isp_Deploy_'
       AND ISNULL(g.logkey,0) = 0
       ORDER BY s.name

   OPEN CUR_DEPLOYSP
   
   FETCH NEXT FROM CUR_DEPLOYSP INTO @c_ExeSPName 
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN      
   	  EXEC('EXEC ' + @c_ExeSPname)        
   	  
    	SELECT @n_err = @@ERROR
	   	IF @n_err <> 0
	   	BEGIN
	   		 SELECT @n_continue = 3
				 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60000   
				 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Execute Deployment Failed. (' + RTRIM(ISNULL(@c_ExeSPname,'')) +') (isp_AutoDeployment)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
				 GOTO ENDPROC
			END
			ELSE
			BEGIN
				 INSERT INTO IDS_GENERALLOG (UDF04, UDF01, UDF05)
				 VALUES ('AUTODEPLOYED',@c_ExeSPname, SUSER_SNAME())
      	 --EXEC('DROP PROCEDURE ' + @c_ExeSPname)        	
      	 	 
    	   SELECT @n_err = @@ERROR
	   	   IF @n_err <> 0
	   	   BEGIN
	   	   	 SELECT @n_continue = 3
			   	 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60010   
			   	 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT IDS_GENERALLOG Failed. (' + RTRIM(ISNULL(@c_ExeSPname,'')) +') (isp_AutoDeployment)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
			   	 GOTO ENDPROC
			   END
		  END 
      FETCH NEXT FROM CUR_DEPLOYSP INTO @c_ExeSPName
   END 
   CLOSE CUR_DEPLOYSP
   DEALLOCATE CUR_DEPLOYSP 
   
ENDPROC: 
 
   IF @n_continue=3  -- Error Occured - Process And Return
	 BEGIN
	    SELECT @b_success = 0
	    IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
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
  	  execute nsp_logerror @n_err, @c_errmsg, 'isp_AutoDeployment'
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

GO