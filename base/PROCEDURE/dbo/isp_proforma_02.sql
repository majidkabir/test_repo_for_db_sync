SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_proforma_02                                    */
/* Creation Date: 2009-12-07                            		            */
/* Copyright: IDS                                                       */
/* Written by: GTGoh                                         			   */
/*                                                                      */
/* Purpose:  MBOL Gatepass for Unilever Philippines     				  	   */
/*                                                                      */
/* Input Parameters:  @c_mbolkey  - MBOL Key         							*/
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_proforma_02                			*/
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  RMC from MBOL                                            */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 06-Nov-2012  SWYep     DM integrity - Update EditDate (SW01)         */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[isp_proforma_02] (@c_mbolkey NVARCHAR(10)) 
AS
BEGIN
   SET NOCOUNT ON			
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE   @n_continue	     int,
		       @c_errmsg			  NVARCHAR(255),
		       @b_success			  int,
		       @n_err				  int,
		       @n_cnt             int,
		       @c_ExternMBOLKey  NVARCHAR(30),
		       @c_facility        NVARCHAR(5),
		       @c_keyname         NVARCHAR(30),
		       @c_printflag       NVARCHAR(1)
	
	SELECT @n_continue = 1, @n_err = 0, @c_errmsg = '', @b_success = 1, @n_cnt = 0, @c_printflag = 'Y'
		      
   SELECT @c_ExternMBOLKey = MBOL.ExternMBOLKey, @c_facility = MBOL.Facility
   FROM MBOL (NOLOCK)
   WHERE Mbolkey = @c_mbolkey
   
   SELECT @n_cnt = @@ROWCOUNT
   
   IF ISNULL(RTRIM(@c_ExternMBOLKey),'') = '' AND @n_cnt > 0
   BEGIN
   	 SELECT @c_printflag = 'N'
   	 
   	 SELECT @c_keyname = Code
   	 FROM CODELKUP (NOLOCK)
   	 WHERE ListName = 'BOL_NCOUNT' 
   	 AND Short = @c_facility
   	
   	 IF ISNULL(RTRIM(@c_keyname),'') = ''
   	 BEGIN
        SELECT @n_continue = 3
        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62313   
        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': CODELKUP LISTNAME BOL_NCOUNT Retrieving Failed For Facility '+RTRIM(@c_facility)+' (isp_proforma_02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
   	 END 
   	 
   	 IF @n_continue = 1 or @n_continue = 2
   	 BEGIN
   	    EXECUTE nspg_GetKey 
   	    		@c_keyname,
   	    		10,   
   	    		@c_ExternMBOLKey OUTPUT,
   	    		@b_success   	 OUTPUT,
   	    		@n_err       	 OUTPUT,
   	    		@c_errmsg    	 OUTPUT
   	    		
   	    IF @n_err <> 0 
   	    BEGIN
         	 SELECT @n_continue = 3
   	    END
   	    ELSE
   	    BEGIN
   	    	  --BEGIN TRAN
	 	    	  UPDATE MBOL WITH (ROWLOCK)
   	    	  SET ExternMBOLKey = @c_ExternMBOLKey,
						--BookingReference = ISNULL(@cBookingReference,BookingReference),
                  Editdate = GETDATE(),            --(SW01)						
   	    	      TrafficCop = NULL   	    	      
   	    	  WHERE Mbolkey = @c_mbolkey
   	    	  
   	    	  SELECT @n_err = @@ERROR
           IF @n_err <> 0 
           --BEGIN
              --WHILE @@TRANCOUNT > 0 
                    --COMMIT TRAN 
           --END 	
           --ELSE
           BEGIN
              --ROLLBACK TRAN 
              SELECT @n_continue = 3
              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62314   
              SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update MBOL Failed. (isp_proforma_02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
   	       END
   	    END
   	  END
   END

   Declare @cInvoice as NVARCHAR(10), @cBookingReference as NVARCHAR(195)
	  					
	  SELECT MBOLDetail.InvoiceNo 
		INTO #TempInvoice
	  	FROM MBOLDetail(Nolock)
		WHERE Mbolkey = @c_mbolkey 
	   AND ISNULL(MBOLDetail.InvoiceNo,'') <> ''
		
		DECLARE C_INVOICE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                                         
			  SELECT DISTINCT ISNULL(RTRIM(InvoiceNo), '')                                                                                  
				 FROM #TempInvoice                                                                            
	                                                                       
		OPEN C_INVOICE
		FETCH NEXT FROM C_INVOICE INTO @cInvoice  

		WHILE @@FETCH_STATUS <> -1 
		BEGIN
			IF ISNULL(@cBookingReference,'') = ''
			BEGIN
				SET @cBookingReference = RTRIM(@cInvoice)
			END
			ELSE
			BEGIN
				SET @cBookingReference = RTRIM(@cBookingReference) + ',' + RTRIM(@cInvoice)
			END
			FETCH NEXT FROM C_INVOICE INTO @cInvoice     
		END
		CLOSE C_INVOICE
		DEALLOCATE C_INVOICE
		
	  DROP Table #TempInvoice
	
   IF @n_continue = 1 OR @n_continue = 2		 	   	   	   		  
   BEGIN
		SELECT	MB.MBOLKey, MB.ExternMBOLKey,
					MD.InvoiceNo,
					MB.editdate AS DispDate,
					CN.company	AS Consignee,
					CN.Address1 AS DelAddress1,
					CN.Address2 AS DelAddress2,
					CN.Address3 AS DelAddress3,
					FC.Descr		AS FromWhse,
					ST.Company	AS Shipper,
					FW.Company	AS Forwarder,
					MB.USERDEFINE05 AS ShipperRef,
					MB.USERDEFINE09 AS ForwarderRef,	
					FW.Address1	AS ForwarderAd1,
					FW.Address2	AS ForwarderAd2,
					MB.VesselQualifier AS VanType,
					MB.USERDEFINE10 AS VanNum,
					PD.sku	AS SKU,
					SK.descr AS SkuDesc,
					GroupSKU = isnull(sk.BUSR5,''), 
					GroupDSC = case when isnull(sk.BUSR5,'') = 'BR' then  'BARS   '  
									 when isnull(sk.BUSR5,'') <> 'BR' then 'OTHERS' END,
					casekg	= ROUND( ISNULL(sum((PD.QTY/PK.CASECNT) * round(SK.STDGROSSWGT*PK.CASECNT,3) ),0) ,3),
					casemeasur = ROUND( ISNULL(sum((PD.QTY/PK.CASECNT) * round(SK.STDCUBE*PK.CASECNT,3) ),0) ,3),
					caseamount = ROUND( ISNULL(sum((PD.QTY/PK.CASECNT) * SK.cost),0),3),  
					casecnt = ROUND( ISNULL(sum(PD.QTY/PK.CASECNT ),0) ,3),
					PreparedBy = MB.EditWho,
					OthReference1 = Convert(NVARCHAR(200), CLK.long),
--					OthReference2 = MB.BookingReference,
					OthReference2 = @cBookingReference,
					OthReference3 = convert(NVARCHAR(200),MB.Remarks),
					@c_printflag as printflag
		FROM PICKDETAIL  PD  (nolock)  
			  inner join ORDERDETAIL OD (nolock)  
					 on OD.OrderKey+OD.sku+OD.OrderLineNumber = PD.Orderkey+PD.sku+PD.OrderLineNumber  
			  inner join ORDERS OH       (nolock)  
					 on OD.orderkey = Oh.OrderKey  
			  inner join STORER ST    (nolock)  
					 on OH.storerkey = ST.storerkey and ST.type = '1'
			  inner join SKU SK          (nolock)  
					 on OD.storerkey+od.sku = SK.storerkey + SK.sku  
			  inner join PACK PK         (nolock) 
					 on PD.packkey = pk.packkey 
			  inner join MBOLDETAIL MD (nolock) 
					 on OD.mbolkey+OD.loadkey+OD.orderkey = MD.MBOLKEY + MD.LOADKEY + MD.Orderkey  
			  inner join MBOL MB         (nolock)  
					 on OD.mbolkey = MB.mbolkey  
			  left outer join STORER CN    (nolock)  
					 on MB.ConsigneeAccountCode = CN.storerkey  
			  inner join FACILITY FC  (nolock)  
					 on MB.FACILITY = FC.FACILITY  
			  inner join STORER FW    (nolock)  
					 on MB.Carrierkey = FW.storerkey and FW.type = '3'
			  inner join CODELKUP  CLK (nolock) 
					 on MB.Transmethod = CLK.code and CLK.listname = 'TRANSMETH'
		  where  MB.MBOLKEY = @c_mbolkey and PD.qty > 0 and MB.Status = '9' 
		  group by  
			 MB.MBOLKey
			, MB.ExternMBOLKey
			,  CN.company 
			,  CN.Address1
			,  CN.Address2
			,  CN.Address3
			, FC.Descr
			, MB.USERDEFINE05
			, MB.USERDEFINE09
			,  MD.InvoiceNo
			,   PD.sku  
			,  SK.descr 
			, ST.Company
			, FW.Company
			, FW.Address1
			, FW.Address2
			, MB.VesselQualifier
			, MB.USERDEFINE10
			, isnull(sk.BUSR5,'')
			,convert(NVARCHAR(200),MB.Remarks)
			, MB.editdate
			, MB.EditWho 
			,  CLK.long
			,  MB.BookingReference

   END
            
   IF @n_continue = 3
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_proforma_02'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
END  	                                    

GO