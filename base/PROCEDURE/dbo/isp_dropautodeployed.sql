SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_DropAutoDeployed                               */
/* Creation Date: 28-Oct-2015                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Drop Auto deployed Script for new PBD                       */
/*          Refer to isp_AutoDeployment                                 */
/*                                                                      */
/* Called By: SQL Job                                                   */ 
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

CREATE PROCEDURE [dbo].[isp_DropAutoDeployed]
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,
           @n_cnt int,
           @n_starttcnt int,
           @b_success int,
           @n_err int,
           @c_errmsg nvarchar(250),
           @c_exespname nvarchar(30)
                               
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt = @@TRANCOUNT, @c_errmsg='', @n_err=0 

   BEGIN TRAN
   	
   DECLARE CUR_DEPLOYEDSP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT DISTINCT s.name 
       FROM dbo.sysobjects s
       JOIN IDS_GENERALLOG g (NOLOCK) ON g.UDF04 = 'AUTODEPLOYED' AND s.name = g.UDF01
       WHERE s.type = 'P' 
       AND ISNULL(g.UDF02,'') <> 'SPDROPPED'
       ORDER BY s.name

   OPEN CUR_DEPLOYEDSP
   
   FETCH NEXT FROM CUR_DEPLOYEDSP INTO @c_ExeSPName 
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN      
   	  EXEC('DROP PROCEDURE ' + @c_ExeSPname)        	

    	SELECT @n_err = @@ERROR
	   	IF @n_err <> 0
	   	BEGIN
	   		 SELECT @n_continue = 3
				 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 50100   
				 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Drop Stored Procedure Failed. (' + RTRIM(ISNULL(@c_ExeSPname,'')) +') (isp_DropAutoDeployed)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
				 GOTO ENDPROC
			END
			ELSE
			BEGIN
				 UPDATE IDS_GENERALLOG WITH (ROWLOCK)
				 SET UDF02 = 'SPDROPPED'
				 WHERE UDF04 = 'AUTODEPLOYED' 
				 AND UDF01 = @c_ExeSPname 

    	   SELECT @n_err = @@ERROR
	   	   IF @n_err <> 0
	   	   BEGIN
	   	   	 SELECT @n_continue = 3
			   	 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 50110   
			   	 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE IDS_GENERALLOG Failed. (' + RTRIM(ISNULL(@c_ExeSPname,'')) +') (isp_DropAutoDeployed)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
			   	 GOTO ENDPROC
			   END
			END

      FETCH NEXT FROM CUR_DEPLOYEDSP INTO @c_ExeSPName
   END 
   CLOSE CUR_DEPLOYEDSP
   DEALLOCATE CUR_DEPLOYEDSP 
   
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
  	  execute nsp_logerror @n_err, @c_errmsg, 'isp_DropAutoDeployed'
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