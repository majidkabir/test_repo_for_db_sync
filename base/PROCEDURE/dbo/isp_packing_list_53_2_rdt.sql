SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: isp_packing_list_53_2_rdt                             	   */
/* Creation Date: 03-Jan-2020                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-11529 - [JP] Daniel Wellington - Packing List for B2B   */
/*           - CR                                                       */
/*          Notes: Duplicate from isp_packing_list_53_2_rdt and modified */
/*                                                                      */
/* Input Parameters:   @c_loadkey   - Loadkey                           */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: RCM	Report	                                             */
/*                                                                      */
/* PVCS Version: 1.1		                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver.  Purposes                                 */
/* 2021-05-18   WLChooi  1.1   WMS-17031 - Add AltSKU based on Codelkup */
/*                             (WL01)                                   */
/************************************************************************/

CREATE PROC [dbo].[isp_packing_list_53_2_rdt] (@c_pickslipno NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE  @c_orderkey   NVARCHAR(10),
				--@c_pickslipno NVARCHAR(10),
				@c_invoiceno  NVARCHAR(10),
				@c_storerkey  NVARCHAR(18),
				@b_success    int,
				@n_err        int,
				@c_errmsg     NVARCHAR(255)

  
  DECLARE @c_getorderkey     NVARCHAR(10),
          @c_Preorderkey     NVARCHAR(10),
          @c_OHNotes         NVARCHAR(250),
          @c_SplitOHNotes    NVARCHAR(250),
          @c_getsku          NVARCHAR(20),
          @c_MergeSku        NVARCHAR(500),
          @c_ODNotes         NVARCHAR(250),
          @c_PreODNotes      NVARCHAR(250),
          @c_DelimiterSign   NVARCHAR(1),
          @n_Recno           INT,
          @n_ttlcnt          INT,
          @n_seqno           INT,
          @c_ColValue        NVARCHAR(150) ,
          @c_premergesku     NVARCHAR(500),
          @c_lastrec         NVARCHAR(5),
          @c_GMergeSku       NVARCHAR(20)

   SET @c_DelimiterSign = '|'

   CREATE table #TMP_ODNotes (
		 Pickslipno NVARCHAR(20),
		 Orderkey   NVARCHAR(20),
		 ODNotes    NVARCHAR(250),
		 mergesku   NVARCHAR(500)

		 )
   --CS01 START
   CREATE table #TMP_PACKINST (
		 Orderkey   NVARCHAR(20),
		 pcode      NVARCHAR(20),
		 storerkey  NVARCHAR(20),
		 PackInst   NVARCHAR(50)

		 )
   --CS01 END

   /*INSERT INTO #TMP_PACKINST (orderkey,pcode,storerkey,PackInst)
   SELECT DISTINCT od.orderkey,c.code, od.storerkey,c.code + '(' + c.short + ')'
   FROM codelkup  c (NOLOCK)
   JOIN orderdetail od (NOLOCK) on od.storerkey = c.storerkey 
   AND  substring(od.userdefine03,1,4) = c.code
   WHERE listname='DWVAS'
   --AND  od.loadkey = @c_loadkey
   AND od.Orderkey = @c_getorderkey*/

	SELECT PACKDETAIL.PickSlipNo,
      PackedQty=SUM(PACKDETAIL.Qty),      
      SKU.DESCR,   
      SKU.Sku,   
      SKU.STDNETWGT,   
      SKU.STDCUBE,   
      SKU.STDGROSSWGT,  
      ORDERS.InvoiceNo,
      ORDERS.OrderKey,   
      ORDERS.LoadKey,
      ORDERS.StorerKey,   
      ORDERS.ConsigneeKey,   
      STORER.Company,   
      ORDERS.DeliveryDate,              
      ORDERS.BuyerPO,   
      ORDERS.ExternOrderKey,               
      ORDERS.Route,   
      ORDERS.Stop,   
      ORDERS.Door,           
      ORDERS.C_CONTACT1,
      ORDERS.BilltoKey, 
      PACK.CaseCnt,       
      PACK.PackUOM1,   
      PACK.PackUOM3,
      PACK.Qty,      
      PACK.PackUOM4,  
      PACK.Pallet,    
      billto.company as B_company,
      billto.address1 as B_address1,
      billto.address2 as B_address2,
      billto.address3 as B_address3,
      billto.address4 as B_address4,
      consignee.company as C_company,
      consignee.address1 as C_address1,
      consignee.address2 as C_address2,
      consignee.address3 as C_address3,
      consignee.address4 as C_address4,
      ORDERS.PrintFlag,
      Notes=CONVERT(NVARCHAR(250),ORDERS.Notes),
      Prepared = CONVERT(NVARCHAR(10), Suser_Sname()),
      ORDERS.LoadKey as Rdd, --ORDERS.Rdd,
      sku.susr3,
      CODELKUP.description as principal,
      ORDERS.Facility, -- Add by June 11.Jun.03 (SOS11736)
      FacilityDescr = Facility.Descr, -- Add by June 11.Jun.03 (SOS11736)
	   Custbarcode = CONVERT(NVARCHAR(15),BILLTO.Notes1), -- SOS37766
	   ISNULL(SKU.Busr6, 0) as Busr6,  -- SOS37766
	   CONVERT(NVARCHAR(250),ORDERS.Notes) as splitohnotes,
      AltSKU = CASE WHEN ISNULL(CL.Code,'') = '' THEN '' ELSE SKU.ALTSKU END   --WL01  
	INTO	#RESULT
	FROM 	PACKHEADER (Nolock)
   JOIN PACKDETAIL (NOLOCK) 
      ON PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo
   JOIN ORDERS (Nolock)
      ON ORDERS.OrderKey = PACKHEADER.OrderKey
   JOIN STORER (Nolock)
      ON ORDERS.StorerKey = STORER.StorerKey
   LEFT OUTER JOIN STORER billto (nolock)
      ON billto.storerkey = ORDERS.billtokey
   LEFT OUTER JOIN STORER consignee (nolock)
      ON consignee.storerkey = ORDERS.consigneekey
   JOIN SKU (Nolock)
      ON SKU.StorerKey = ORDERS.Storerkey and
         SKU.Sku = PACKDETAIL.Sku
	JOIN PACK (Nolock) 
      ON PACK.PackKey = SKU.PackKey
   LEFT OUTER JOIN CODELKUP (nolock)
      ON codelkup.listname = 'PRINCIPAL' and
         codelkup.code = sku.susr3
   INNER JOIN FACILITY (nolock) 
      ON Facility.Facility = ORDERS.Facility -- Add by June 11.Jun.03 (SOS11736)
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.LISTNAME = 'DWWHSDN')         --WL01
                                      AND (CL.Storerkey = ORDERS.StorerKey) --WL01
                                      AND (CL.Code = ORDERS.ConsigneeKey)   --WL01
	WHERE	PACKHEADER.PickSlipNo = @c_pickslipno
	GROUP BY 
      PACKDETAIL.PickSlipNo,   
      SKU.DESCR,   
      SKU.Sku,   
      SKU.STDNETWGT,   
      SKU.STDCUBE,   
      SKU.STDGROSSWGT,  
      ORDERS.InvoiceNo,
      ORDERS.OrderKey,
      ORDERS.LoadKey,
      ORDERS.StorerKey,   
      ORDERS.ConsigneeKey,   
      STORER.Company,   
      ORDERS.DeliveryDate,              
      ORDERS.BuyerPO,   
      ORDERS.ExternOrderKey,               
      ORDERS.Route,   
      ORDERS.Stop,   
      ORDERS.Door,           
      ORDERS.C_CONTACT1,
      ORDERS.BilltoKey, 
      PACK.CaseCnt,       
      PACK.PackUOM1,   
      PACK.PackUOM3,
      PACK.Qty,      
      PACK.PackUOM4,  
      PACK.Pallet,    
      billto.company,
      billto.address1,
      billto.address2,
      billto.address3,
      billto.address4,
      consignee.company,
      consignee.address1,
      consignee.address2,
      consignee.address3,
      consignee.address4,
      ORDERS.PrintFlag,
      CONVERT(NVARCHAR(250),ORDERS.Notes),
      -- ORDERS.Rdd,
      sku.susr3,
      CODELKUP.description,
      ORDERS.Facility, -- Add by June 11.Jun.03 (SOS11736)
      Facility.Descr, -- Add by June 11.Jun.03 (SOS11736)
		CONVERT(NVARCHAR(15), BILLTO.Notes1), -- SOS37766
		SKU.Busr6, -- SOS37766
      CASE WHEN ISNULL(CL.Code,'') = '' THEN '' ELSE SKU.ALTSKU END   --WL01  

   /*
   select @c_orderkey = ''
   while (1=1)
   begin -- while 1
      select @c_orderkey = min(orderkey)
      from #result
      where orderkey > @c_orderkey
         and (pickslipno is null or pickslipno = '')

      if isnull(@c_orderkey, '0') = '0'
         break
      
      select @c_storerkey = storerkey
      from #result
      where orderkey = @c_orderkey

      EXECUTE nspg_GetKey
         'PICKSLIP',
         9,   
 	 	@c_pickslipno     OUTPUT,
   		@b_success   	 OUTPUT,
   		@n_err       	 OUTPUT,
   		@c_errmsg    	 OUTPUT

      SELECT @c_pickslipno = 'P' + @c_pickslipno            

      -- Start : SOS31698, Add by June 31.Jan.2005
      -- Honielot request to update the previous P/S# so that same SO# only has 1 P/S#
      -- This is to prevent scanning of previous P/S#
		IF EXISTS (SELECT 1 FROM PICKHEADER (NOLOCK) 
					  WHERE Orderkey = @c_orderkey AND Wavekey = @c_loadkey AND zone = '3'
					  AND   PickHeaderkey <> @c_pickslipno)
		BEGIN
			DELETE FROM PICKHEADER WHERE Orderkey = @c_orderkey AND Wavekey = @c_loadkey AND zone = '3'
		END
		-- End : SOS31698

      INSERT PICKHEADER (pickheaderkey, wavekey, orderkey, zone)
				VALUES (@c_pickslipno, @c_loadkey, @c_orderkey, '3')

      -- update PICKDETAIL
		UPDATE PICKDETAIL
		SET trafficcop = null,
		    pickslipno = @c_pickslipno
		WHERE orderkey = @c_orderkey

		-- update print flag
		UPDATE ORDERS
		SET trafficcop = null,
		    printflag = 'Y'
		WHERE orderkey = @c_orderkey   */

     -- if exists (select 1 
     --            from storerconfig (nolock)
     --            where storerkey = @c_storerkey
     --               and configkey in ('WTS-ITF','LORITF')
     --               and svalue = '1')
   		---- update result table
   		--UPDATE #RESULT
   		--SET pickslipno = @c_pickslipno,
     --          rdd = @c_loadkey
   		--WHERE orderkey = @c_orderkey
     -- else
     --    UPDATE #RESULT
   		--SET pickslipno = @c_pickslipno
   		--WHERE orderkey = @c_orderkey
   --end -- while 1

	SET @c_Preorderkey = ''
	SET @c_MergeSku = ''
	SET @c_SplitOHNotes = ''
	SET @c_PreODNotes = ''
	SET @n_Recno = 1
   SET @n_ttlcnt = 1
	SET @c_premergesku = ''
	SET @c_lastrec = 'N'
	SET @c_GMergeSku = ''

   /*DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT Orderkey,notes,ODnotes   
   FROM   #RESULT RS   
   WHERE loadkey = @c_loadkey  
   and isnull(ODnotes,'') <> ''
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_getorderkey,@c_OHNotes,@c_ODNotes    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  

	  --    DECLARE C_DelimSplit CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   --      SELECT SeqNo, ltrim(Rtrim(ColValue))      
   --      FROM dbo.fnc_DelimSplit(@c_DelimiterSign,@c_OHNotes)    
			--where colvalue <>''
    
   --      OPEN C_DelimSplit    
   --      FETCH NEXT FROM C_DelimSplit INTO @n_SeqNo, @c_ColValue    
    
   --     WHILE (@@FETCH_STATUS=0)     
   --     BEGIN 

		 --  select @n_ttlcnt = count(1)
		 --  FROM dbo.fnc_DelimSplit(@c_DelimiterSign,@c_OHNotes) 
			--where colvalue <>'' 
			
			--IF  @n_Recno <> @n_ttlcnt
			--BEGIN 
		
		 --   SET @c_SplitOHNotes = @c_SplitOHNotes + @c_ColValue + char(13)
   --      END
			--ELSE
			--BEGIN
			 
			--  SET @c_SplitOHNotes = @c_SplitOHNotes + @c_ColValue
			--END

			--set @n_Recno = @n_Recno + 1

		 --FETCH NEXT FROM C_DelimSplit INTO @n_SeqNo, @c_ColValue    
   --    END -- WHILE (@@FETCH_STATUS <> -1) AND @n_Continue <> 3    
    
   --    CLOSE C_DelimSplit    
   --    DEALLOCATE C_DelimSplit


  --   SET @c_Preorderkey = @c_getorderkey
      
	 -- IF @c_Preorderkey <> @c_getorderkey
  --    BEGIN
	 --  SEt @c_premergesku = ''
	 ---- update #RESULT
	 ---- set mergesku = @c_premergesku
	 ---- where orderkey =@c_getorderkey
  --   END

		 SET @n_Recno = 1
         SET @n_ttlcnt = 1

	 DECLARE CUR_SKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
       SELECT DISTINCT sku
       FROM   #RESULT RS   
       WHERE orderkey = @c_getorderkey
	   and  ODnotes = @c_ODNotes  

		OPEN CUR_SKU    
        FETCH NEXT FROM CUR_SKU INTO @c_getsku  
    
        WHILE (@@FETCH_STATUS=0)     
        BEGIN 

		  SELECT @n_ttlcnt = COUNT(DISTINCT SKU)
		  FROM   #RESULT RS   
          WHERE orderkey = @c_getorderkey
		  and  ODnotes = @c_ODNotes

		--  select @n_Recno '@n_Recno' ,@n_ttlcnt '@n_ttlcnt',@c_MergeSku '@c_MergeSku'
		  
	 

	  if @c_PreODNotes = ''  
	  BEGIN
	      IF @n_Recno = 1
		  BEGIN 
	       SET @c_MergeSku = @c_ODNotes + ':'
          END
      END
	  ELSE if   @c_PreODNotes <> @c_ODNotes
	  BEGIN
	   IF @c_Preorderkey = @c_getorderkey
	   BEGIN
	     SET @c_MergeSku = @c_MergeSku + '|' + @c_ODNotes + ':'
       END
	   ELSE
	   BEGIN
	     SET @c_MergeSku = @c_ODNotes + ':'
	   END
      END

	    SET @c_Preorderkey = @c_getorderkey
		SET @c_PreODNotes = @c_ODNotes

	
		  IF @n_Recno <> @n_ttlcnt --and  @c_PreODNotes = @c_ODNotes
		  BEGIN
		    
		    SET @c_MergeSku = @c_MergeSku + @c_getsku + '-'

		  END
		  ELSE
		  BEGIN
		     SET @c_MergeSku = @c_MergeSku + @c_getsku
			 
		  END

		  set @n_Recno = @n_Recno + 1
		  
		  
		   FETCH NEXT FROM CUR_SKU INTO @c_getsku    
         END    
    
       CLOSE CUR_SKU    
       DEALLOCATE CUR_SKU

	   IF NOT EXISTS (SELECT 1 FROM #TMP_ODNotes WHERE orderkey = @c_getorderkey and ODNotes = @c_ODNotes)
	   BEGIN
	      INSERT INTO #TMP_ODNotes (Pickslipno,Orderkey,ODNotes,mergesku)
		  VALUES ('',@c_getorderkey,@c_ODNotes,@c_MergeSku)
		    --SET @c_premergesku = @c_premergesku + @c_MergeSku
		 
	   END
	     -- select * from #TMP_ODNotes
	    -- select 'B4',@c_premergesku '@c_premergesku',@c_MergeSku '@c_MergeSku'

	   if @c_premergesku <> @c_MergeSku
	   BEGIN
	     IF @c_premergesku = '' 
		 BEGIN
		   SET @c_premergesku = @c_MergeSku
		 END
		 ELSE
		 BEGIN
	       SET @c_premergesku = @c_premergesku + '| '+ @c_MergeSku
	     END
       END
	 --  select @c_premergesku '@c_premergesku',@c_MergeSku '@c_MergeSku'


	        
   FETCH NEXT FROM CUR_RESULT INTO @c_getorderkey,@c_OHNotes,@c_ODNotes  
   END  

   
	
	  --and  notes = @c_OHNotes 
	  --and  ODnotes = @c_ODNotes

     */
	-- return result set
	SELECT R.PickSlipNo,
          SUM(R.PackedQty) AS PackedQty,  
          R.DESCR,   
          R.Sku,   
          R.STDNETWGT,   
          R.STDCUBE,   
          R.STDGROSSWGT,  
          R.InvoiceNo,
          R.OrderKey,   
          R.LoadKey,
          R.StorerKey,   
          R.ConsigneeKey,   
          R.Company,   
          R.DeliveryDate,              
          R.BuyerPO,   
          R.ExternOrderKey,               
          R.Route,   
          R.Stop,   
          R.Door,           
          R.C_CONTACT1,
          R.BilltoKey, 
          R.CaseCnt,       
          R.PackUOM1,   
          R.PackUOM3,
          R.Qty,      
          R.PackUOM4,  
          R.Pallet,    
          R.B_company,
          R.B_address1,
          R.B_address2,
          R.B_address3,
          R.B_address4,
          R.C_company,
          R.C_address1,
          R.C_address2,
          R.C_address3,
          R.C_address4,
          R.PrintFlag,
          '',--R.Notes,
          R.Prepared,
          R.Rdd, 
          R.susr3,
          R.principal,
          R.Facility, -- Add by June 11.Jun.03 (SOS11736)
          R.FacilityDescr, -- Add by June 11.Jun.03 (SOS11736)
          R.Custbarcode , -- SOS37766
          R.Busr6,  -- SOS37766
          R.splitohnotes,
          R.ALTSKU   --WL01
	FROM #RESULT R
	LEFT JOIN #TMP_ODNotes ODN ON ODN.orderkey = R.orderkey 
	group by R.PickSlipNo,     
		      R.DESCR,   
		      R.Sku,   
		      R.STDNETWGT,   
		      R.STDCUBE,   
		      R.STDGROSSWGT,  
		      R.InvoiceNo,
		      R.OrderKey,   
		      R.LoadKey,
		      R.StorerKey,   
		      R.ConsigneeKey,   
		      R.Company,   
		      R.DeliveryDate,              
		      R.BuyerPO,   
		      R.ExternOrderKey,               
		      R.Route,   
		      R.Stop,   
		      R.Door,           
		      R.C_CONTACT1,
		      R.BilltoKey, 
		      R.CaseCnt,       
		      R.PackUOM1,   
		      R.PackUOM3,
		      R.Qty,      
		      R.PackUOM4,  
		      R.Pallet,    
		      R.B_company,
		      R.B_address1,
		      R.B_address2,
		      R.B_address3,
		      R.B_address4,
		      R.C_company,
		      R.C_address1,
		      R.C_address2,
		      R.C_address3,
		      R.C_address4,
		      R.PrintFlag,
		      --R.Notes,
		      R.Prepared,
		      R.Rdd, 
		      R.susr3,
		      R.principal,
		      R.Facility, -- Add by June 11.Jun.03 (SOS11736)
		      R.FacilityDescr, -- Add by June 11.Jun.03 (SOS11736)
		      R.Custbarcode , -- SOS37766
		      R.Busr6,  -- SOS37766
		      R.splitohnotes,
            R.ALTSKU   --WL01
	order by r.pickslipno,r.orderkey,r.sku

	-- drop table
	DROP TABLE #RESULT
END

GO