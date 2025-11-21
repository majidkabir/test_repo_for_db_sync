SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_UpdateSkuImageJob                              */
/* Creation Date: 20-Apr-2015                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Generate and update Sku Image Path. Move image form upload  */
/*          folder to assigned sub-folder                               */
/*                                                                      */
/* Called By: SQL JOB                                                   */ 
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
/* 06-Feb-2017  TLTING    1.1   debug flag                              */
/************************************************************************/

CREATE  PROCEDURE [dbo].[isp_UpdateSkuImageJob]
   @c_storerkey NVARCHAR(15)=''
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue  INT,
           @n_starttcnt INT,
           @c_currstorerkey NVARCHAR(15),
           @b_success   INT ,
           @n_err       INT ,
           @c_errmsg    NVARCHAR(225),
           @c_SkuImageServer NVARCHAR(200),
           @c_NSQLValue NVARCHAR(30),
           @n_debug     INT            
                         
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0 
   SET @n_debug = 0

   SELECT @c_SkuImageServer = ISNULL(NSQLDescrip,''),
          @c_NSQLValue = ISNULL(NSQLValue,'')
   FROM NSQLCONFIG (NOLOCK)     
   WHERE ConfigKey='SkuImageServer' 
         
   IF ISNULL(@c_SkuImageServer,'') = '' OR @c_NSQLValue <> '1'
	 BEGIN
  	   SELECT @n_continue = 3
		   SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60001   
		   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Sku Image Server Not Yet Setup/Enable In System Config. (isp_UpdateSkuImageJob)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
		   GOTO ENDPROC
   END   

   IF @n_debug = 1
   BEGIN
      SELECT 'SkuImageServer' = @c_SkuImageServer, 'NSQLValue' = @c_NSQLValue
   END

   IF OBJECT_ID('tempdb..#DirTree') IS NOT NULL
      DROP TABLE #DirTree

   CREATE TABLE #DirTree (
     Id int identity(1,1),
     SubDirectory nvarchar(255),
     Depth smallint,
     FileFlag bit  -- 0=folder 1=file
    )
      
   INSERT INTO #DirTree (SubDirectory, Depth, FileFlag)
   EXEC master..xp_dirtree @c_SkuImageServer, 2, 1    --folder, depth 0=all(default) 1..x, 0=not list file(default) 1=list file

   DECLARE STORER_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT Storerkey
      FROM STORER (NOLOCK)
      WHERE Storerkey = CASE WHEN ISNULL(@c_Storerkey,'') <> '' THEN @c_Storerkey ELSE Storerkey END
      AND Type = '1'

      OPEN STORER_CUR
	            
	    FETCH NEXT FROM STORER_CUR INTO @c_CurrStorerkey
                                            
      WHILE @@FETCH_STATUS <> -1
      BEGIN
      	  BEGIN TRAN
          
         IF @n_debug = 1
         BEGIN
            SELECT 'Storerkey' = @c_CurrStorerkey 
         END


          EXEC isp_UpdateSkuImage
               @c_currstorerkey ,
               @b_success    OUTPUT,
               @n_err        OUTPUT,
               @c_errmsg     OUTPUT               
          
          IF @b_success <> 1
             ROLLBACK TRAN
          ELSE
             COMMIT TRAN   
                
    	    FETCH NEXT FROM STORER_CUR INTO @c_CurrStorerkey
      END
      CLOSE STORER_CUR
      DEALLOCATE STORER_CUR      
      
ENDPROC: 

   IF OBJECT_ID('tempdb..#DirTree') IS NOT NULL
   DROP TABLE #DirTree
 
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
  	  execute nsp_logerror @n_err, @c_errmsg, 'isp_UpdateSkuImageJob'
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