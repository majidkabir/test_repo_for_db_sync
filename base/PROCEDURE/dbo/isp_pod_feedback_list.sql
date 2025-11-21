SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_POD_Feedback_List                      	      */
/* Creation Date:  2006-05-26	                                          */
/* Copyright: IDS                                                       */
/* Written by:  ONGGB                                                   */
/*                                                                      */
/* Purpose:  r_dw_POD_Feedback_List		                                 */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  			                                                */
/*                                                                      */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author    	Purposes                                     */
/*	2006-11-17	ONG01			Correct DateRange                            */
/* 2007-02-14  James      change Addwho to Editwho                      */
/*	2007-04-18	ONG02			SOS73229 - Add Sorting Parameter,            */
/*									      JOIN with GUI.Externorderkey 	         */
/* 2007-05-04  FKLIM      SOS74228 - Change POD.Status >= 7             */
/* 2007-07-16  TLTING     SQL2005, Status >= 7 put '7'                  */
/* 2013-08-12  NJOW01     279769-Add delivery date                      */
/* 26-Nov-2013 TLTING     Change user_name() to SUSER_SNAME()           */
/************************************************************************/


CREATE  PROC [dbo].[isp_POD_Feedback_List] (
     @c_StorerKey   	 NVARCHAR(15),
     @c_OrderDateMin   NVARCHAR(10),
     @c_OrderDateMax   NVARCHAR(10),
     @c_PODRecDateMin   NVARCHAR(10),
     @c_PODRecDateMax   NVARCHAR(10),
     @c_ConsigneeStart  NVARCHAR(15), 
     @c_ConsigneeEnd   NVARCHAR(15),
     @c_MBOLStart 	 NVARCHAR(10), 
     @c_MBOLEnd  		 NVARCHAR(10), 
     @c_LoadStart 	 NVARCHAR(10), 
     @c_LoadEnd  		 NVARCHAR(10), 
     @c_SortType		 NVARCHAR(1) = '1',				-- ONG02
	  @b_debug				int	  = 0   
) AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

		DECLARE @cOrdDateMin datetime
				, @cOrdDateMax datetime
				, @cPODDateMin datetime
				, @cPODDateMax datetime
				, @cSortBy NVARCHAR(1)		/* O= OrderDate ; P= PODReceivedDate	*/
				, @cCheckOrder			int				
				, @cCheckPOD			int				
				, @cOrdDateRange NVARCHAR(50)		
				, @cPODDateRange  NVARCHAR(50)		
				, @cConsigneeRange NVARCHAR(50)		
			   , @cMBOLRange 		 NVARCHAR(50) 	
			   , @cLoadRange 		 NVARCHAR(50)		

		-- SET Selection Range to be shown on report
		SELECT @cConsigneeRange  = 'FROM ' + dbo.fnc_RTrim(@c_ConsigneeStart) + ' to ' + dbo.fnc_RTrim(@c_ConsigneeEnd)	
				,@cMBOLRange  = 'FROM ' + dbo.fnc_RTrim(@c_MBOLStart) + ' to ' + dbo.fnc_RTrim(@c_MBOLEnd)
				,@cLoadRange  = 'FROM ' + dbo.fnc_RTrim(@c_LoadStart) + ' to ' + dbo.fnc_RTrim(@c_LoadEnd)	
				,@cCheckOrder = 0			
				,@cCheckPOD = 0			



		DECLARE	@n_continue int		/* continuation flag 
														1=Continue
														2=failed but continue processsing 
														3=failed do not continue processing 
														4=successful but skip furthur processing */                                               
	            ,@n_starttcnt int    -- Holds the current transaction count                                                                                           
		         ,@n_err int	
					,@c_errmsg NVARCHAR(250)
					,@c_ExecStatements  nvarchar(4000)

    	/* Set default values for variables */
     	SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @cSortBy = ''

		
		/* String to date convertion */
		If dbo.fnc_RTrim(@c_OrderDateMin) <> '' AND dbo.fnc_RTrim(@c_OrderDateMin) <> NULL 
			AND dbo.fnc_RTrim(@c_OrderDateMax) <> '' AND dbo.fnc_RTrim(@c_OrderDateMax) <> NULL 
		BEGIN
				SELECT @cSortBy = 'O'		-- OrderDate entered, sort by OrderDate first
				SELECT @cCheckOrder = 1		
				SELECT @cOrdDateMin = Convert(datetime, @c_OrderDateMin)
				If @@ERROR <> 0	GOTO Invalid_Date_Range
				SELECT @cOrdDateMax = Convert(datetime, @c_OrderDateMax)
				If @@ERROR <> 0	GOTO Invalid_Date_Range
-- 				SELECT @cOrdDateMin = DATEADD(day, -1, @cOrdDateMin)		-- ONG01
-- 				SELECT @cOrdDateMax =  DATEADD(day, 1, @cOrdDateMax)		-- ONG01
				SELECT @cOrdDateRange = 'From ' + @c_OrderDateMin + ' to ' + @c_OrderDateMax	
				IF @b_debug = 1 PRINT 'DATE:' + CONVERT(CHAR(10), @cOrdDateMin, 111) + ' ~ ' + CONVERT(CHAR(10), @cOrdDateMax, 111) 
		END

		If dbo.fnc_RTrim(@c_PODRecDateMin) <> '' AND dbo.fnc_RTrim(@c_PODRecDateMin) <> NULL 
			AND dbo.fnc_RTrim(@c_PODRecDateMax) <> '' AND dbo.fnc_RTrim(@c_PODRecDateMax) <> NULL 
		BEGIN
				IF @cSortBy <> 'O'
					SELECT @cSortBy = 'P'		-- OrderDate entered, sort by OrderDate first
				SELECT @cCheckPOD = 1		
				SELECT @cPODDateMin= Convert(datetime, @c_PODRecDateMin)
				If @@ERROR <> 0	GOTO Invalid_Date_Range
				SELECT @cPODDateMax = Convert(datetime, @c_PODRecDateMax)
				If @@ERROR <> 0	GOTO Invalid_Date_Range
-- 				SELECT @cPODDateMin = DATEADD(day, -1, @c_PODRecDateMin)		-- ONG01
-- 				SELECT @cPODDateMax =  DATEADD(day, 1, @c_PODRecDateMax)		-- ONG01
				SELECT @cPODDateRange  = 'From ' + @c_PODRecDateMin + ' to ' + @c_PODRecDateMax		
				IF @b_debug = 1 PRINT 'DATE:' + CONVERT(CHAR(10), @cPODDateMin, 111) + ' ~ ' + CONVERT(CHAR(10), @cPODDateMax, 111) 
		END

		IF @b_debug = 1
		BEGIN
			If @cSortBy	=  'O'
			 	PRINT 'Storerkey='+ @c_StorerKey + ' Sort By OrderDate Range: ' 
					+ CONVERT(CHAR(10), @cOrdDateMin, 111) + ' - ' + CONVERT(CHAR(10), @cOrdDateMax, 111)
			Else If @cSortBy	=  'P'
				PRINT 'Storerkey='+ @c_StorerKey + ' Sort By PODReceivedDate Range: ' 
					+ CONVERT(CHAR(10), @cPODDateMax, 111) + ' - ' + CONVERT(CHAR(10), @cPODDateMax, 111)
		END 

		GOTO Valid_Date_Range
		
		/* Invalid Date Range - Set Error Msg then stop proceeding*/
		Invalid_Date_Range:
		IF @n_continue = 3 
		BEGIN
	     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=510420    -- Should Be Set To The SQL Errmessage but I don't know how to do so.
	     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+"Invalid Date Range (isp_POD_Feedback_List)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
			GOTO Final
		END

		/* Date Validation DONE!!! Continue the process */
		Valid_Date_Range:		
		If @cSortBy not in ('P', 'O')
      BEGIN
           SELECT @n_continue = 3 
           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=510421    -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+"Incomplete Date Range (isp_POD_Feedback_List)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END               
		 

     
		IF @n_continue=1 or @n_continue=2
		BEGIN
			SELECT @c_ExecStatements = ''
			--sos#66820 changed by James from Addwho to Editwho
			SELECT @c_ExecStatements = N'SELECT ORDERS.StorerKey
													,ORDERS.Facility
													,ORDERS.Orderkey
													,ORDERS.OrderDate 
													,POD.PodReceivedDate 													
													,POD.ExternOrderKey
													,ORDERS.InvoiceNo
													,GUI.BillDate
													,ORDERS.Consigneekey 
													,ORDERS.C_Company 
													,GUI.PaymentTerm
													,POD.ActualDeliveryDate
													,GUI.TotalSalesAmt
													,ORDERS.DeliveryNote
													,POD.EditWho
													,CONVERT(CHAR(20), (Suser_Sname())) As sUser' +
													', N''' + dbo.fnc_RTrim(@cOrdDateRange) + ''' OrdDateRange ' + 
													', N''' + dbo.fnc_RTrim(@cPODDateRange) + ''' PODDateRange ' +	
													', N''' + dbo.fnc_RTrim(@cConsigneeRange)+''' ConsigneeRange ' +
											      ', N''' + dbo.fnc_RTrim(@cMBOLRange) + ''' MBOLRange ' +
											      ', N''' + dbo.fnc_RTrim(@cLoadRange) + ''' LoadRange ' +
											      ', OrderDetail.Lottable01 ' +
											      ', ORDERS.Deliverydate ' +
												'FROM ORDERS (NOLOCK) ' +
                                    'JOIN ORDERDETAIL (NOLOCK) ON Orders.Orderkey = Orderdetail.Orderkey ' + 
												'JOIN POD (NOLOCK) ON POD.Orderkey = ORDERS.Orderkey
												LEFT OUTER JOIN GUI (NOLOCK) ON GUI.InvoiceNo = ORDERS.InvoiceNo ' +
 												'									AND GUI.ExternOrderkey = ORDERS.Externorderkey ' + -- ONG02												
											   'WHERE ORDERS.StorerKey = N''' + dbo.fnc_RTrim(@c_StorerKey) + ''' ' 
                                     + 'AND POD.Status >= ''7'' '     --FKLIM SOS74228           -- put in ' in the status check
                                     + 'AND ORDERS.Consigneekey BETWEEN N''' + dbo.fnc_RTrim(@c_ConsigneeStart) + ''' AND N''' 
												 + dbo.fnc_RTrim(@c_ConsigneeEnd) + ''' ' 
												 + 'AND POD.MBOLKEY BETWEEN N''' + dbo.fnc_RTrim(@c_MBOLStart) + ''' AND N''' 	
												 + dbo.fnc_RTrim(@c_MBOLEnd) + ''' '														
												 + 'AND POD.LoadKEY BETWEEN N''' + dbo.fnc_RTrim(@c_LoadStart) + ''' AND N''' 	
												 + dbo.fnc_RTrim(@c_LoadEnd) + ''' '														
			
			/* WHEN Order.Date entered */
			IF @cCheckOrder = 1
				SELECT @c_ExecStatements = @c_ExecStatements 
												+ 'AND ORDERS.OrderDate BETWEEN ''' + CONVERT(CHAR(10), @cOrdDateMin ,120) 
												+ ''' AND ''' + CONVERT(CHAR(10), @cOrdDateMax ,120)+ ''' '

			/* WHEN POD.PodReceivedDate entered */
			IF @cCheckPOD = 1
				SELECT @c_ExecStatements = @c_ExecStatements 
												+ 'AND POD.PodReceivedDate BETWEEN ''' + CONVERT(CHAR(10), @cPODDateMin ,120) 
												+ ''' AND ''' + CONVERT(CHAR(10), @cPODDateMax ,120) + ''' '

				SELECT @c_ExecStatements = @c_ExecStatements + 'GROUP BY ORDERS.StorerKey
													,ORDERS.Facility
													,ORDERS.Orderkey
													,ORDERS.OrderDate 
													,POD.PodReceivedDate 													
													,POD.ExternOrderKey
													,ORDERS.InvoiceNo
													,GUI.BillDate
													,ORDERS.Consigneekey 
													,ORDERS.C_Company 
													,GUI.PaymentTerm
													,POD.ActualDeliveryDate
													,GUI.TotalSalesAmt
													,ORDERS.DeliveryNote
													,POD.EditWho
											      ,OrderDetail.Lottable01 ' +
												'  ,ORDERS.ExternOrderkey, ORDERS.Deliverydate ' 		-- ONG02

			IF @cSortBy = 'O'
			BEGIN
				IF @c_SortType = '1'		-- ONG02				
					SELECT @c_ExecStatements = 
						@c_ExecStatements  + 'ORDER BY ORDERS.Facility, ORDERS.OrderDate ,POD.PodReceivedDate ,ORDERS.Orderkey' 
				ELSE
					SELECT @c_ExecStatements = 
						@c_ExecStatements  + 'ORDER BY ORDERS.Facility ,ORDERS.Storerkey ,ORDERS.ExternOrderkey ,ORDERS.OrderDate ,POD.PodReceivedDate ' 	-- ONG02
			END
			IF @cSortBy = 'P'
			BEGIN
				IF @c_SortType = '1'		-- ONG02				
					SELECT @c_ExecStatements = 
						@c_ExecStatements + 'ORDER BY ORDERS.Facility, POD.PodReceivedDate ,ORDERS.OrderDate ,ORDERS.Orderkey' 
				ELSE
					SELECT @c_ExecStatements = 
						@c_ExecStatements + 'ORDER BY ORDERS.Facility ,ORDERS.Storerkey ,ORDERS.ExternOrderkey ,POD.PodReceivedDate ,ORDERS.OrderDate' 	-- ONG02
			END

			IF @b_debug = 1	PRINT @c_ExecStatements + master.dbo.fnc_GetCharASCII(13)
			EXEC sp_executesql @c_ExecStatements 
			
			SELECT @n_err = @@ERROR
			IF @n_err <> 0
			BEGIN
				SELECT @n_continue = 3 
				SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=510422    -- Should Be Set To The SQL Errmessage but I don't know how to do so.
				SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+"Fail (isp_POD_Feedback_List)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
			END               
		END  /* continue */


	FINAL:
	IF @n_continue=3  -- Error Occured - Process And Return
	BEGIN
		execute nsp_logerror @n_err, @c_errmsg, 'isp_POD_Feedback_List'
		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
		RETURN
	END    

END
/*****************************************************************/
/* End Create Procedure Here                                     */
/*****************************************************************/  


GO