SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_AssignLanes                                     */
/* Creation Date:  26-SEP-2022                                          */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  WMS-20687 TH Assign Lanes by orders                        */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  Assign lane                                              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver  Purposes                                   */
/* 26-SEP-2022 NJOW     1.0  DEVOPS Combine Script                      */
/************************************************************************/

CREATE PROC [dbo].[isp_AssignLanes]
   @c_Module NVARCHAR(15),  --LOADPLAN, MBOL 
   @c_RequestOrders_Json NVARCHAR(MAX),
   @c_RequestLanes_Json NVARCHAR(MAX),
   @b_Success int OUTPUT,
   @n_err     int OUTPUT,
   @c_errmsg  NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON   -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue         INT,
           @n_StartTranCnt     INT,
           @c_Dockey           NVARCHAR(10),
           @c_Consigneekey     NVARCHAR(15),
           @c_Externorderkey   NVARCHAR(50),
           @c_LineNo           NVARCHAR(5),
           @n_LineNo           INT,
           @c_Loc              NVARCHAR(10),  
           @c_LocationCategory NVARCHAR(10),
           @n_OrdersAssigned   INT = 0,
           @n_LanesAssigned    INT = 0
           
   DECLARE @t_orders TABLE (
      Dockey NVARCHAR(10),
      Consigneekey NVARCHAR(15),
      ExternOrderkey NVARCHAR(50))
      
   DECLARE @t_lanes TABLE (
      Loc NVARCHAR(10))
            
   SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1, @b_Success = 1, @n_err = 0, @c_errmsg = ''
   
   IF @c_Module = ''
      SET @c_Module = 'LOADPLAN'
   
   IF @n_StartTranCnt = 0
      BEGIN TRAN
      	
   IF @n_continue IN(1,2)  	
   BEGIN
      IF ISNULL(@c_Module,'') NOT IN('LOADPLAN','MBOL')
      BEGIN
        SELECT @n_continue = 3
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid module. only for LOADPLAN and MBOL . (isp_AssignLanes)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   	   	
        GOTO QUIT_SP 
      END   	
   	
      IF ISNULL(@c_RequestOrders_Json,'') = ''
      BEGIN
        SELECT @n_continue = 3
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No orders selected to assign lane . (isp_AssignLanes)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   	   	
        GOTO QUIT_SP 
      END
      
      IF ISNULL(@c_RequestLanes_Json,'') = ''
      BEGIN
        SELECT @n_continue = 3
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No Lanes selected to assign. (isp_AssignLanes)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   	   	
        GOTO QUIT_SP 
      END
   END
   
   IF @n_continue IN(1,2)
   BEGIN
   	  INSERT INTO @t_orders
      SELECT dockey      
           , consigneekey
           , externorderkey      
      FROM OPENJSON(@c_RequestOrders_Json)
           WITH (dockey         NVARCHAR(10) '$.dockey'
                ,consigneekey   NVARCHAR(15) '$.consigneekey'
                ,externorderkey NVARCHAR(50) '$.externorderkey')

   	  INSERT INTO @t_lanes
      SELECT loc      
      FROM OPENJSON(@c_RequestLanes_Json)
           WITH (loc            NVARCHAR(10) '$.loc')                            
           
      IF (SELECT COUNT(1) FROM @t_orders) = 0
      BEGIN
        SELECT @n_continue = 3
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No orders selected to assign lane or invalid data. (isp_AssignLanes)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   	   	
        GOTO QUIT_SP       	
      END

      IF (SELECT COUNT(1) FROM @t_lanes) = 0
      BEGIN
        SELECT @n_continue = 3
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No lanes selected to assign or invalid data. (isp_AssignLanes)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   	   	
        GOTO QUIT_SP       	
      END
   END
   
   IF @n_continue IN(1,2)
   BEGIN
      DECLARE cur_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT Dockey, Consigneekey, Externorderkey
         FROM @t_orders
         ORDER BY ExternOrderkey
      
      OPEN cur_ORD    
            
      FETCH NEXT FROM cur_ORD INTO @c_DocKey, @c_ConsigneeKey, @c_ExternOrderkey     
        
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
      BEGIN      
      	 SELECT @c_LineNo = '', @n_LineNo = 0
      	 
      	 IF @c_Module ='LOADPLAN'
      	 BEGIN
      	 	  DELETE FROM LOADPLANLANEDETAIL
      	 	  WHERE Loadkey = @c_Dockey
      	 	  AND ExternOrderkey = @c_ExternOrderkey
      	 	  AND Consigneekey = @c_Consigneekey
      	 	  AND ISNULL(Loc,'') = ''
      	 	  
      	 	  SELECT @c_LineNo = MAX(LP_LaneNumber)
      	 	  FROM LOADPLANLANEDETAIL (NOLOCK)
            WHERE Loadkey = @c_Dockey
      	 	  AND ExternOrderkey = @c_ExternOrderkey
      	 	  AND Consigneekey = @c_Consigneekey      	 	        	 	  
      	 END
      	 ELSE IF @c_Module ='MBOL'
      	 BEGIN
      	 	  DELETE FROM LOADPLANLANEDETAIL
      	 	  WHERE Mbolkey = @c_Dockey
      	 	  AND ExternOrderkey = @c_ExternOrderkey
      	 	  AND Consigneekey = @c_Consigneekey
      	 	  AND ISNULL(Loc,'') = ''

      	 	  SELECT @c_LineNo = MAX(LP_LaneNumber)
      	 	  FROM LOADPLANLANEDETAIL (NOLOCK)
            WHERE Mbolkey = @c_Dockey
      	 	  AND ExternOrderkey = @c_ExternOrderkey
      	 	  AND Consigneekey = @c_Consigneekey      	 	        	 	  
      	 END
      	 
      	 IF ISNULL(@c_LineNo,'') <> ''
      	    SET @n_LineNo = CAST(@c_LineNo AS INT)      	 
      	 
      	 DECLARE cur_Lane CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
      	   SELECT LN.Loc, ISNULL(LOC.LocationCategory,'')
      	   FROM @t_lanes LN
      	   JOIN LOC (NOLOCK) ON LN.Loc = LOC.Loc
      	   ORDER BY LN.Loc

         OPEN cur_Lane    
            
         FETCH NEXT FROM cur_Lane INTO @c_Loc, @c_LocationCategory
        
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
         BEGIN            	 
         	  SET @n_LineNo = @n_LineNo + 1
         	  SET @c_LineNo = RIGHT('00000' + CAST(@n_LineNo AS NVARCHAR),5)                   
         	  
         	  IF @c_Module = 'LOADPLAN'
         	  BEGIN
         	      INSERT INTO LOADPLANLANEDETAIL (Loadkey, ExternOrderkey, Consigneekey, lp_lanenumber, locationcategory, loc)             
                VALUES (@c_Dockey, @c_ExternOrderkey, @c_Consigneekey, @c_LineNo, @c_LocationCategory, @c_Loc)
            END
            ELSE IF @c_Module = 'MBOL'
            BEGIN
         	      INSERT INTO LOADPLANLANEDETAIL (Mbolkey, ExternOrderkey, Consigneekey, lp_lanenumber, locationcategory, loc)             
                VALUES (@c_Dockey, @c_ExternOrderkey, @c_Consigneekey, @c_LineNo, @c_LocationCategory, @c_Loc)
            END

            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert LOADPLANLANEDETAIL Failed. (isp_AssignLanes)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            END            
            
            FETCH NEXT FROM cur_Lane INTO @c_Loc,  @c_LocationCategory
         END
         CLOSE cur_Lane
         DEALLOCATE cur_Lane
         
         SET @n_OrdersAssigned = @n_OrdersAssigned + 1
      	 
   	     FETCH NEXT FROM cur_ORD INTO @c_DocKey, @c_ConsigneeKey, @c_ExternOrderkey     
   	  END
   	  CLOSE cur_ORD
   	  DEALLOCATE cur_ORD      
   END
END

QUIT_SP:

IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
 SELECT @b_success = 0
 IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
 BEGIN
  ROLLBACK TRAN
 END
 ELSE
 BEGIN
  WHILE @@TRANCOUNT > @n_StartTranCnt
  BEGIN
   COMMIT TRAN
  END
 END
 execute nsp_logerror @n_err, @c_errmsg, 'isp_AssignLanes'
 --RAISERROR @n_err @c_errmsg
 RETURN
END
ELSE
BEGIN
 SELECT @b_success = 1
 
 IF @n_OrdersAssigned > 0
 BEGIN
 	  SELECT @n_LanesAssigned = COUNT(1) FROM @t_lanes
    SELECT @c_ErrMsg = 'Total ' + CAST(@n_OrdersAssigned AS NVARCHAR) + ' Order(s) are Assigned ' + CAST(@n_LanesAssigned AS NVARCHAR) + ' lane(s) Sucessfully.'
 END
 
 WHILE @@TRANCOUNT > @n_StartTranCnt
 BEGIN
  COMMIT TRAN
 END
 RETURN
END

GO