SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_POD_non_Feedback_List                          */
/* Creation Date:  2006-05-26	                                          */
/* Copyright: IDS                                                       */
/* Written by:  ONGGB                                                   */
/*                                                                      */
/* Purpose:  r_dw_POD_non_Feedback_List										   */
/*                                                                      */
/* Input Parameters:  							                              */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  									                              */
/*                                                                      */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author    	Purposes                                     */
/*	2006-11-17	ONG01			Correct DateRange 									*/
/* 11.Jan.2007	June			SOS63921 - Add Status in report parameter 	*/
/*	2007-04-18	ONG02			SOS73229 - Add Sorting Parameter, 				*/
/*									JOIN with GUI.Externorderkey 						*/
/* 2007-05-04  FKLIM       SOS74228 - Change POD.Status >= 7            */
/* 2007-07-16  TLTING      SQL2005, Status >= 7 put '7'                 */
/* 26-Nov-2013  TLTING     Change user_name() to SUSER_SNAME()          */
/************************************************************************/


CREATE PROC [dbo].[isp_POD_non_Feedback_List] (
     @c_StorerKey   	 NVARCHAR(15),
     @c_OrderDateMin   NVARCHAR(10),
     @c_OrderDateMax   NVARCHAR(10),
     @c_MBOLDateMin   NVARCHAR(10),
     @c_MBOLDateMax   NVARCHAR(10),
     @c_ConsigneeStart  NVARCHAR(15), 
     @c_ConsigneeEnd   NVARCHAR(15), 
     @c_MBOLStart 	 NVARCHAR(10), 
     @c_MBOLEnd  		 NVARCHAR(10), 
     @c_LoadStart 	 NVARCHAR(10), 
     @c_LoadEnd  		 NVARCHAR(10), 
	  @c_PODStatus		 NVARCHAR(10), 
     @c_SortType		 NVARCHAR(1) = '1',				-- ONG02
  	  @b_debug		int		  = 0 
) AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

		DECLARE @cOrdDateMin 		datetime
				, @cOrdDateMax 		datetime
				, @cMBOLDateMin 	datetime
				, @cMBOLDateMax 	datetime
				, @cSortBy 			 NVARCHAR(1)
				, @cCheckOrder			int				
				, @cCheckMBOL			int				
				, @cOrdDateRange 	 NVARCHAR(50)		
				, @cMBOLDateRange  NVARCHAR(50)		
				, @cConsigneeRange NVARCHAR(50)
			   , @cMBOLRange 		 NVARCHAR(50)
			   , @cLoadRange 		 NVARCHAR(50)
				, @cStorerkey		 NVARCHAR(15)			
				, @cFacility		 NVARCHAR(5)			
				, @nGrandTotal			int				
				, @nTotalOrder			int			
				

		SELECT @cConsigneeRange  = 'FROM ' + dbo.fnc_RTrim(@c_ConsigneeStart) + ' to ' + dbo.fnc_RTrim(@c_ConsigneeEnd)	
				,@cMBOLRange  = 'FROM ' + dbo.fnc_RTrim(@c_MBOLStart) + ' to ' + dbo.fnc_RTrim(@c_MBOLEnd)
				,@cLoadRange  = 'FROM ' + dbo.fnc_RTrim(@c_LoadStart) + ' to ' + dbo.fnc_RTrim(@c_LoadEnd)	
				,@cCheckOrder = 0			
				,@cCheckMBOL = 0			
				

		DECLARE	 @n_continue int		/* continuation flag 
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
				, @cOrdDateRange = '', @cMBOLDateRange = ''	-- ONG01

		/* DROP TempTb before creating it*/
	   IF OBJECT_ID ('tempdb..#TempTb') IS NOT NULL	      DROP TABLE #TempTb
		
		/* Create TempTb */
		SELECT ORDERS.StorerKey
				,ORDERS.Facility
				,ORDERS.Orderkey
				,Orders.Type
				,ORDERS.OrderDate 
				,POD.ExternOrderKey 
				,Orders.InvoiceNo 
				,GUI.BillDate 
				,ORDERS.Consigneekey 
				,ORDERS.C_Company 
				,ORDERS.C_Address1
				,POD.ActualDeliveryDate 
				,POD.LoadKey
				,POD.MBOLKey	
				,POD.Status 
				,CONVERT(NVARCHAR(255), POD.Notes2 ) AS NOTES2 
				,CASE WHEN POD.Status >= '7' THEN 1 ELSE 0 END CNT4 --FKLIM SOS74228      -- tlting sql2005 put ' in status check
				,CONVERT(NVARCHAR(20), '') As sUser 
				,dbo.fnc_RTrim(@cOrdDateRange)  OrdDateRange 
				,dbo.fnc_RTrim(@cMBOLDateRange) MBOLDateRange
				,dbo.fnc_RTrim(@cConsigneeRange) ConsigneeRange 
		      ,dbo.fnc_RTrim(@cMBOLRange)  MBOLRange
		      ,dbo.fnc_RTrim(@cLoadRange)  LoadRange
		      ,OrderDetail.Lottable01
				,0 As TotalOrder
				,0 As GrandTotal
			INTO #TempTb
			FROM ORDERS (NOLOCK) 
		   JOIN ORDERDETAIL (NOLOCK) ON Orders.Orderkey = Orderdetail.Orderkey
			JOIN POD (NOLOCK) ON POD.Orderkey = ORDERS.Orderkey
			LEFT OUTER JOIN GUI (NOLOCK) ON GUI.InvoiceNo = ORDERS.InvoiceNo 
		where 1=2

		
		/* String to date convertion */
		If dbo.fnc_RTrim(@c_OrderDateMin) <> '' AND dbo.fnc_RTrim(@c_OrderDateMin) <> NULL 
			AND dbo.fnc_RTrim(@c_OrderDateMax) <> '' AND dbo.fnc_RTrim(@c_OrderDateMax) <> NULL 
		BEGIN
				SELECT @cSortBy = 'O'		-- OrderDate entered, sort by OrderDate first
				SELECT @cCheckOrder = 1		-- ONG04
				SELECT @cOrdDateMin = Convert(datetime, @c_OrderDateMin)
				If @@ERROR <> 0	GOTO Invalid_Date_Range
				SELECT @cOrdDateMax = Convert(datetime, @c_OrderDateMax)
				If @@ERROR <> 0	GOTO Invalid_Date_Range
-- 				SELECT @cOrdDateMin = DATEADD(day, -1, @cOrdDateMin)
-- 				SELECT @cOrdDateMax =  DATEADD(day, 1, @cOrdDateMax)
				SELECT @cOrdDateRange = 'From ' + @c_OrderDateMin + ' to ' + @c_OrderDateMax		
				IF @b_debug = 1 PRINT 'DATE:' + CONVERT(NVARCHAR(10), @cOrdDateMin, 111) + ' ~ ' + CONVERT(NVARCHAR(10), @cOrdDateMax, 111) 
		END

		If dbo.fnc_RTrim(@c_MBOLDateMin) <> '' AND dbo.fnc_RTrim(@c_MBOLDateMin) <> NULL 
			AND dbo.fnc_RTrim(@c_MBOLDateMax) <> '' AND dbo.fnc_RTrim(@c_MBOLDateMax) <> NULL 
		BEGIN
				IF @cSortBy <> 'O' 
					SELECT @cSortBy = 'P'		-- OrderDate entered, sort by OrderDate first
				SELECT @cCheckMBOL = 1
				SELECT @cMBOLDateMin= Convert(datetime, @c_MBOLDateMin)
				If @@ERROR <> 0	GOTO Invalid_Date_Range
				SELECT @cMBOLDateMax = Convert(datetime, @c_MBOLDateMax)
				If @@ERROR <> 0	GOTO Invalid_Date_Range
-- 				SELECT @cMBOLDateMin = DATEADD(day, -1, @c_MBOLDateMin)
-- 				SELECT @cMBOLDateMax =  DATEADD(day, 1, @c_MBOLDateMax)
				SELECT @cMBOLDateRange = 'From ' + @c_MBOLDateMin + ' to ' + @c_MBOLDateMax
				IF @b_debug = 1 
					PRINT 'DATE:' + CONVERT(NVARCHAR(10), @cMBOLDateMin, 111) + ' ~ ' + CONVERT(NVARCHAR(10), @cMBOLDateMax, 111) 
		END

		IF @b_debug = 1
		BEGIN
			If @cSortBy	=  'O'
			 	PRINT 'Storerkey='+ @c_StorerKey + ' Sort By OrderDate Range: ' 
					+ CONVERT(NVARCHAR(10), @cOrdDateMin, 111) + ' - ' + CONVERT(NVARCHAR(10), @cOrdDateMax, 111)
			Else If @cSortBy = 'P'	
				PRINT 'Storerkey='+ @c_StorerKey + ' Sort By MBOL Ship Date Range: ' 
					+ CONVERT(NVARCHAR(10), @cMBOLDateMax, 111) + ' - ' + CONVERT(NVARCHAR(10), @cMBOLDateMax, 111)
		END 

		GOTO Valid_Date_Range
		
		/* Invalid Date Range - Set Error Msg then stop proceeding*/
		Invalid_Date_Range:
		IF @n_continue = 3 
		BEGIN
	     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=51042    -- Should Be Set To The SQL Errmessage but I don't know how to do so.
	     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+"Invalid Date Range (isp_POD_non_Feedback_List)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
			GOTO Final
		END

		/* Date Validation DONE!!! Continue the process */
		Valid_Date_Range:		
		If @cSortBy not in ('P', 'O')
      BEGIN
           SELECT @n_continue = 3 
           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=51042    -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+"Incomplete Date Range (isp_POD_non_Feedback_List)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END               
		 

     
		IF @n_continue=1 or @n_continue=2
		BEGIN
			SELECT @c_ExecStatements = ''
			
			SELECT @c_ExecStatements = N'SELECT ORDERS.StorerKey
													,ORDERS.Facility
													,ORDERS.Orderkey
													,Orders.Type
													,ORDERS.OrderDate 
													,POD.ExternOrderKey 
													,Orders.InvoiceNo 
													,GUI.BillDate 
													,ORDERS.Consigneekey 
													,ORDERS.C_Company 
													,ORDERS.C_Address1
													,POD.ActualDeliveryDate 
													,POD.LoadKey
													,POD.MBOLKey	
													,POD.Status 
													,CONVERT(NVARCHAR(255), POD.Notes2 ) AS NOTES2 
													,CNT4= CASE WHEN POD.Status >= ''7'' THEN 1 ELSE 0 END           
													,CONVERT(NVARCHAR(20), (Suser_Sname())) As sUser ' +        
													', N''' + dbo.fnc_RTrim(@cOrdDateRange) + ''' OrdDateRange ' + 			
													', N''' + dbo.fnc_RTrim(@cMBOLDateRange)+ ''' MBOLDateRange ' +			
													', N''' + dbo.fnc_RTrim(@cConsigneeRange)+''' ConsigneeRange ' + 			
											      ', N''' + dbo.fnc_RTrim(@cMBOLRange) + ''' MBOLRange ' + 			 
											      ', N''' + dbo.fnc_RTrim(@cLoadRange) + ''' LoadRange ' + 			
											      ',OrderDetail.Lottable01 ' +
													',0 ' + 								
													',0 ' +								
												'FROM ORDERS (NOLOCK) ' +
                                    'JOIN ORDERDETAIL (NOLOCK) ON Orders.Orderkey = Orderdetail.Orderkey ' + 
												'JOIN POD (NOLOCK) ON POD.Orderkey = ORDERS.Orderkey
												LEFT OUTER JOIN GUI (NOLOCK) ON GUI.InvoiceNo = ORDERS.InvoiceNo 
																						AND GUI.ExternOrderkey = ORDERS.Externorderkey ' + -- ONG02
											   'WHERE ORDERS.StorerKey = N''' + dbo.fnc_RTrim(@c_StorerKey) + ''' ' 
												 + 'AND ORDERS.Consigneekey BETWEEN N''' + dbo.fnc_RTrim(@c_ConsigneeStart) + ''' AND N'''
												 + dbo.fnc_RTrim(@c_ConsigneeEnd) + ''' '		-- ONG01
												 + 'AND POD.MBOLKEY BETWEEN N''' + dbo.fnc_RTrim(@c_MBOLStart) + ''' AND N''' 
												 + dbo.fnc_RTrim(@c_MBOLEnd) + ''' '
												 + 'AND POD.LoadKEY BETWEEN N''' + dbo.fnc_RTrim(@c_LoadStart) + ''' AND N''' 
												 + dbo.fnc_RTrim(@c_LoadEnd) + ''' '
												 + 'AND POD.Status = N''' + dbo.fnc_RTrim(@c_PODStatus) + ''' ' -- SOS63921
                                                                                           -- FKLIM SOS74228 for POD.Status >= 7
                                                                                           -- tlting put ' in check

			IF @cCheckOrder = 1
				SELECT @c_ExecStatements = @c_ExecStatements 
												+ 'AND ORDERS.OrderDate BETWEEN ''' + CONVERT(CHAR(10), @cOrdDateMin ,120) 
												+ ''' AND ''' + CONVERT(CHAR(10), @cOrdDateMax ,120)+ ''' '

			IF @cCheckMBOL = 1
				SELECT @c_ExecStatements = @c_ExecStatements 
												+ 'AND POD.ActualDeliveryDate BETWEEN ''' + CONVERT(CHAR(10), @cMBOLDateMin ,120) 
												+ ''' AND ''' + CONVERT(CHAR(10), @cMBOLDateMax ,120) + ''' '

			SELECT @c_ExecStatements = @c_ExecStatements + 'GROUP BY ORDERS.StorerKey
													,ORDERS.Facility
													,ORDERS.Orderkey
													,Orders.Type
													,ORDERS.OrderDate 
													,POD.ExternOrderKey 
													,Orders.InvoiceNo 
													,GUI.BillDate 
													,ORDERS.Consigneekey 
													,ORDERS.C_Company 
													,ORDERS.C_Address1
													,POD.ActualDeliveryDate 
													,POD.LoadKey
													,POD.MBOLKey	
													,POD.Status 
													,CONVERT(NVARCHAR(255), POD.Notes2 ) 
													,CASE WHEN POD.Status >= ''7'' THEN 1 ELSE 0 END
											      ,OrderDetail.Lottable01 ' +
												'  ,ORDERS.Externorderkey ' 			-- ONG02
                                                                        -- FKLIM SOS74228 for POD.Status >= 7
                                                                        -- tlting put ' in check         

			IF @cSortBy = 'O'
			BEGIN
				IF @c_SortType = '1'		-- ONG02
					SELECT @c_ExecStatements = @c_ExecStatements 
													+ 'ORDER BY ORDERS.Facility, ORDERS.OrderDate ,POD.ActualDeliveryDate ,ORDERS.Orderkey' 
				ELSE							-- ONG02
					SELECT @c_ExecStatements = @c_ExecStatements 
													+ 'ORDER BY ORDERS.Facility ,ORDERS.StorerKey ,ORDERS.ExternOrderkey ,ORDERS.OrderDate ,POD.ActualDeliveryDate ' 
			END
			IF @cSortBy = 'P'
			BEGIN
				IF @c_SortType = '1'		-- ONG02
					SELECT @c_ExecStatements = @c_ExecStatements 
													+ 'ORDER BY ORDERS.Facility ,POD.ActualDeliveryDate ,ORDERS.OrderDate ,ORDERS.Orderkey' 
				ELSE							-- ONG02
					SELECT @c_ExecStatements = @c_ExecStatements 
													+ 'ORDER BY ORDERS.Facility ,ORDERS.StorerKey ,ORDERS.ExternOrderkey ,POD.ActualDeliveryDate ,ORDERS.OrderDate' 
			END

			IF @b_debug = 1	PRINT @c_ExecStatements + master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(13)
			INSERT INTO #TempTb
			EXEC sp_executesql @c_ExecStatements 
			
			SELECT @n_err = @@ERROR
			IF @n_err <> 0
			BEGIN
				SELECT @n_continue = 3 
				SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=51042    -- Should Be Set To The SQL Errmessage but I don't know how to do so.
				SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+"Fail (isp_POD_non_Feedback_List)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
			END             
			
			if @b_debug = 2
			begin
				PRINT 'Full Result... '
				SELECT Orderkey, Status , CNT4, GrandTotal ,TotalOrder   FROM #TempTb  
			end 

			-- Update Total Order base on its Facility and also Grand Total for the Storer
			SELECT @nGrandTotal = Count(*)
			FROM #TempTb 
			GROUP BY Storerkey

			Declare C_Orders cursor local fast_forward read_only for 
			SELECT Storerkey , Facility , Count(*)
			FROM #TempTb 
			GROUP BY Storerkey , Facility 
			
			OPEN C_Orders 
			
			FETCH NEXT FROM C_Orders INTO @cStorerkey ,@cFacility ,@nTotalOrder
			
			WHILE @@Fetch_status <> -1 
			BEGIN
				IF @b_debug = 1 or @b_debug = 2
					SELECT @cStorerkey Storerkey ,@cFacility Facility ,@nTotalOrder TotOrder

				UPDATE #TempTb
				SET GrandTotal = @nGrandTotal, TotalOrder = @nTotalOrder
				WHERE Storerkey = @cStorerkey AND Facility = @cFacility 

				FETCH NEXT FROM C_Orders INTO @cStorerkey ,@cFacility ,@nTotalOrder	
			END
         CLOSE C_Orders      
         DEALLOCATE C_Orders 

			DELETE FROM #TempTb WHERE CNT4 = 1		

			SELECT * FROM #TempTb   

			if @b_debug = 2 
				SELECT Orderkey, Status , CNT4, GrandTotal ,TotalOrder   FROM #TempTb  

		END  /* continue */


	FINAL:
	IF @n_continue=3  -- Error Occured - Process And Return
	BEGIN
		execute nsp_logerror @n_err, @c_errmsg, 'isp_POD_non_Feedback_List'
		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
		RETURN
	END
-- 	ELSE
-- 	BEGIN
-- 		WHILE @@TRANCOUNT > @n_starttcnt
-- 		BEGIN
-- 			COMMIT TRAN
-- 		END
-- 		RETURN
-- 	END

  	IF OBJECT_ID ('tempdb..#TempTb') IS NOT NULL	      DROP TABLE #TempTb    

     

END
/*****************************************************************/
/* End Create Procedure Here                                     */
/*****************************************************************/  

GO