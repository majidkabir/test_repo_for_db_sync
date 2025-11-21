SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_UndoPackConfirmPreCartonize                    */
/* Creation Date: 26-Aug-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Undo pack confirm (pre cartonize)   SOS#142535                   */
/*                                                                      */
/* Called By: nep_w_packing_precartonize_maintenance                    */ 
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
/* 07-Oct-2009  NJOW      1.1   Remove other tables update and just     */
/*                              update packhearder status only          */ 
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_UndoPackConfirmPreCartonize]
   @c_pickslipno    NVARCHAR(10),
   @b_success  int OUTPUT,
   @n_err      int OUTPUT,
   @c_errmsg   NVARCHAR(225) OUTPUT
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int

   DECLARE @c_orderkey NVARCHAR(10),
           @c_loadkey NVARCHAR(30),
           @c_status NVARCHAR(1),
           @c_storerkey NVARCHAR(15),
           @n_cnt int,
           @n_starttcnt int
   
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0 
  
   BEGIN TRAN

   SELECT @c_status = PACKHEADER.Status, @c_orderkey = ISNULL(PACKHEADER.orderkey,''), 
          @c_loadkey = ISNULL(PACKHEADER.Loadkey,''), @c_storerkey = PACKHEADER.StorerKey
   FROM PACKHEADER (NOLOCK)
   WHERE PACKHEADER.Pickslipno = @c_pickslipno
   
   IF @c_status <> '9' 
	 BEGIN
  	  SELECT @n_continue = 3
		  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60098   
		  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Pack Not Confirm Yet. (isp_UndoPackConfirmPreCartonize)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
   END
   
   IF @c_orderkey <> ''
   BEGIN
   	  IF (SELECT COUNT(*) FROM ORDERS(NOLOCK) WHERE Orderkey = @c_orderkey AND Status = '9') > 0
   	  BEGIN
	  	   SELECT @n_continue = 3
			   SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60099   
			   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Order Already Shipped. Undo Pack Confirm Is Not Allowed . (isp_UndoPackConfirmPreCartonize)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
   	  END
   END
   ELSE
   BEGIN
   	  IF (SELECT COUNT(*) FROM LOADPLAN(NOLOCK) WHERE Loadkey = @c_loadkey AND Status = '9') > 0
   	  BEGIN
	  	   SELECT @n_continue = 3
			   SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60100   
			   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': LoadPlan Already Shipped. Undo Pack Confirm Is Not Allowed . (isp_UndoPackConfirmPreCartonize)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
   	  END
   END
   
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
    	UPDATE PACKHEADER WITH (ROWLOCK)
    	SET Status = '0'
	   	WHERE ArchiveCop = NULL
	   	AND Pickslipno = @c_pickslipno	   	
	   	SELECT @n_err = @@ERROR
	   	IF @n_err <> 0
	   	BEGIN
	   		SELECT @n_continue = 3
				SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60101   
				SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PACKHEADER Table. (isp_UndoPackConfirmPreCartonize)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
				GOTO ENDPROC
			END
	   	
	   	/*UPDATE PICKINGINFO WITH (ROWLOCK)
	   	SET ScanOutDate = NULL, TrafficCop = NULL   	     
	   	WHERE PickslipNo = @c_pickslipno
	   	SELECT @n_err = @@ERROR
	   	IF @n_err <> 0
	   	BEGIN
	   		SELECT @n_continue = 3
				SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60102   
				SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PACKINGINFO Table. (isp_UndoPackConfirmPreCartonize)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
				GOTO ENDPROC
			END*/
	   	
	   	IF @c_orderkey <> ''   	  
	   	BEGIN
			 	 /*UPDATE ORDERS WITH (ROWLOCK)
			 	 SET Status = '3' , TrafficCop = NULL
			 	 WHERE OrderKey = @c_orderkey			 	 
 	 	   	 SELECT @n_err = @@ERROR
		   	 IF @n_err <> 0
		   	 BEGIN
	  	 		 SELECT @n_continue = 3
					 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60103   
					 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update ORDERS Table. (isp_UndoPackConfirmPreCartonize)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
					 GOTO ENDPROC
				 END
			 	 
	 		 	 UPDATE ORDERDETAIL WITH (ROWLOCK)
			 	 SET Status = '3', TrafficCop = NULL
			 	 WHERE OrderKey = @c_orderkey
 	 	   	 SELECT @n_err = @@ERROR
		   	 IF @n_err <> 0
		   	 BEGIN
	  	 		 SELECT @n_continue = 3
					 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60104   
					 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update ORDERDETAIL Table. (isp_UndoPackConfirmPreCartonize)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
					 GOTO ENDPROC
				 END
			 	 
			 	 UPDATE PICKDETAIL WITH (ROWLOCK)
			 	 SET Status = '0' 
			 	 WHERE OrderKey = @c_Orderkey		   	 
 	 	   	 SELECT @n_err = @@ERROR
		   	 IF @n_err <> 0
		   	 BEGIN
	  	 		 SELECT @n_continue = 3
					 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60105   
					 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PICKDETAIL Table. (isp_UndoPackConfirmPreCartonize)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
					 GOTO ENDPROC
				 END
			 	 
			 	 UPDATE LOADPLANDETAIL WITH (ROWLOCK)
			 	 SET Status = '3', TrafficCop =  NULL
			 	 WHERE Orderkey = @c_Orderkey
			 	 AND LoadKey = @c_loadkey
 	 	   	 SELECT @n_err = @@ERROR
		   	 IF @n_err <> 0
		   	 BEGIN
	  	 		 SELECT @n_continue = 3
					 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60106   
					 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update LOADPLANDETAIL Table. (isp_UndoPackConfirmPreCartonize)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
					 GOTO ENDPROC
				 END*/			 	 
				 
 	       UPDATE MBOLDETAIL WITH (ROWLOCK)
				 SET TotalCartons = 0,
				     Trafficcop = NULL
				 WHERE Orderkey = @c_orderkey
					 	 
	       SELECT @n_err = @@ERROR
	       IF @n_err <> 0
	       BEGIN
	  	 		 SELECT @n_continue = 3
					 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60112   
	         SELECT @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Update Failed On Table MBOLDETAIL. (isp_UndoPackConfirmPreCartonize)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_errmsg),'') + ' ) '
					 GOTO ENDPROC
	       END
	  	END
			/*ELSE
			BEGIN
			 	 UPDATE ORDERS WITH (ROWLOCK)
			 	 SET Status = '3' , TrafficCop = NULL
			 	 WHERE LoadKey = @c_loadkey
			 	 SELECT @n_err = @@ERROR
		   	 IF @n_err <> 0
		   	 BEGIN
	  	 		 SELECT @n_continue = 3
					 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60107   
					 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update ORDERS Table. (isp_UndoPackConfirmPreCartonize)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
					 GOTO ENDPROC
				 END

	 		 	 UPDATE ORDERDETAIL WITH (ROWLOCK)
			 	 SET Status = '3', TrafficCop = NULL
			 	 WHERE LoadKey = @c_loadkey
 	 	   	 SELECT @n_err = @@ERROR
		   	 IF @n_err <> 0
		   	 BEGIN
	  	 		 SELECT @n_continue = 3
					 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60108   
					 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update ORDERDETAIL Table. (isp_UndoPackConfirmPreCartonize)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
					 GOTO ENDPROC
				 END
			 	 
			 	 UPDATE PICKDETAIL WITH (ROWLOCK)
			 	 SET PICKDETAIL.Status = '0' 
			 	 FROM PICKDETAIL, ORDERS (NOLOCK)
			 	 WHERE PICKDETAIL.OrderKey = ORDERS.OrderKey
			 	 AND ORDERS.Loadkey = @c_loadkey
 	 	   	 SELECT @n_err = @@ERROR
		   	 IF @n_err <> 0
		   	 BEGIN
	  	 		 SELECT @n_continue = 3
					 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60109   
					 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PICKDETAIL Table. (isp_UndoPackConfirmPreCartonize)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
					 GOTO ENDPROC
				 END
			 	 
	 		 	 UPDATE LOADPLANDETAIL WITH (ROWLOCK)
			 	 SET Status = '3', TrafficCop =  NULL
			 	 WHERE LoadKey = @c_loadkey
 	 	   	 SELECT @n_err = @@ERROR
		   	 IF @n_err <> 0
		   	 BEGIN
	  	 		 SELECT @n_continue = 3
					 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60110   
					 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update LOADPLANDETAIL Table. (isp_UndoPackConfirmPreCartonize)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
					 GOTO ENDPROC
				 END
			END*/
	   	
	   	/*SELECT @c_status = MAX(Status)
	   	FROM LOADPLANDETAIL (NOLOCK)
	   	WHERE LoadKey = @c_loadkey
	   	
	   	IF @c_status = '3'
	   	BEGIN
	   		 UPDATE LOADPLAN WITH (ROWLOCK)
	   		 SET Status = '3', TrafficCop = NULL
	   		 WHERE LoadKey = @c_loadkey
	   	END 
	   	ELSE
	   	BEGIN
	   		 UPDATE LOADPLAN WITH (ROWLOCK)
	   		 SET Status = '5', TrafficCop = NULL
	   		 WHERE LoadKey = @c_loadkey
	   	END
      SELECT @n_err = @@ERROR
		  IF @n_err <> 0
		  BEGIN
	  	  SELECT @n_continue = 3
			  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60111   
				SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update LOADPLAN Table. (isp_UndoPackConfirmPreCartonize)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
				GOTO ENDPROC
		  END*/
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
  	  execute nsp_logerror @n_err, @c_errmsg, 'isp_UndoPackConfirmPreCartonize'
	    --RAISERROR @n_err @c_errmsg
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