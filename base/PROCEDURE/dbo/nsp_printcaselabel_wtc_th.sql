SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  nsp_PrintCaseLabel_WTC_TH                         	*/
/* Creation Date: 13-Jan-2006                           		*/
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                          	*/
/*                                                                      */
/* Purpose:  Create to print WTC XDOCK/Indent Case Label 		*/
/*           SOS45051 WTCPH-XDOCK - Print WTC Case Label                */
/*           Notes: 1) This case label can be printed from:             */
/*                     i) XDOCK ASN screen ii) LoadPlan.                */
/*                                                                      */
/*                  2) Label size is 2" x 2"                            */
/*                                                                      */
/* Input Parameters:  @c_refkey, -ExternReceiptKey if type='R', Loadkey */
/*	                if type='L'                    			*/
/*			@c_type	 -'R'(ExternReceiptKey), 'L'(Loadkey)   */
/*                                                                      */
/*                                                                      */
/* Called By:  dw = r_dw_caselabel_wtc_th                		*/
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 28-Feb-2006  MaryVong  Extract StorerSODefault.XDockLane instead of  */
/*                        OrderHeader.ConsigneeKey                      */
/* 09-Mar-2006  MaryVong  SOS47221 Insert blank record to indicate a    */
/*                        group break for label printing (by pickslipno)*/
/* 25-Jul-2008  Vanessa   SOS111881                      -- (Vanessa01) */
/*                        1)Page Break of the report will be by Loc.LocAisle */	
/*						  2)Report sorting by Putaway Zone, LogicalLocation, Location Code, SKU */	
/*									*/				
/************************************************************************/

CREATE PROC [dbo].[nsp_PrintCaseLabel_WTC_TH] (@c_refkey NVARCHAR(20), @c_type NVARCHAR(2)) 
AS
BEGIN
   -- Type = R for ExternReceiptKey, L for LoadKey
   SET NOCOUNT ON			-- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @c_PickDetailKey NVARCHAR(10),
      @c_StorerKey          NVARCHAR(15),
	  @c_Sku			    NVARCHAR(20),
      @c_PackKey            NVARCHAR(10),
	  @n_CaseCnt 		    int,
      @n_Qty                int, 
      @n_NoOfCases          int,
      @c_CaseID             NVARCHAR(10),
      @c_TempCaseID         NVARCHAR(10),
      @c_NewCaseID          NVARCHAR(10),
      @n_CaseID             int,
      @c_NewPickDetailKey   NVARCHAR(10),
      @c_OrderKey           NVARCHAR(10), 
      @c_OrderLineNumber    NVARCHAR(5), 
      @c_PickSlipNo         NVARCHAR(10),
      @n_Cnt                int,
      -- SOS47221
	  @c_ResXDockLane	 NVARCHAR(10),
	  @c_ResSellerName	 NVARCHAR(45), 
	  @c_ResExternPOKey	    NVARCHAR(20),  
	  @c_ResSku			 NVARCHAR(20),  
	  @c_ResSkuDescr	 NVARCHAR(60),
	  @c_ResQty				int,		
	  @c_ResPickSlipNo	 NVARCHAR(10),
	  @c_ResPrevPickSlipNo NVARCHAR(10),
      @c_ResCaseID          NVARCHAR(10), 
	  -- (Vanessa01)
      @c_ResPutAwayZone     NVARCHAR(10), 
      @c_ResLogicalLocation NVARCHAR(18), 
      @c_ResLoc			    NVARCHAR(10), 
      @c_ResLocAisle	    NVARCHAR(10), 
      @c_ResConsigneeKey    NVARCHAR(15), 
      @c_ResRETAILSKU	    NVARCHAR(20), 
      -- (Vanessa01)
	  @n_continue		    int,
	  @n_err			    int,
	  @c_errmsg		        NVARCHAR(255),
	  @b_success		    int,
	  @n_starttcnt          int,
      @b_debug              int

   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT, @b_debug = 0 

   CREATE TABLE #TEMPPICKDETAIL (
			[PickDetailKey]		[char] (10) ,
			[OrderKey]          [char] (10) , 
			[OrderLineNumber]	[char] (5) ,  
			[StorerKey]			[char] (15) ,  
			[Sku]				[char] (20) ,  
			[Qty]				[int] ,		
			[Packkey]			[char] (10) ,
            [UOM]				[char] (10) , 
			[PickSlipNo]		[char] (10) NULL ) 

   -- SOS47221
   CREATE TABLE #TEMPRESULT (
            [RowId]				[int] IDENTITY (1, 1) NOT NULL ,
			[XDockLane]			[char] (10) NULL,
			[SellerName]		[char] (45) NULL, 
			[ExternPOKey]		[char] (20) NULL,  
			[Sku]				[char] (20) NULL,  
			[SkuDescr]			[char] (60) NULL,           
			[Qty]				[int],		
			[PickSlipNo]		[char] (10) NULL,
            [CaseID]			[char] (10) NULL,
			-- (Vanessa01)
			[Loc]				[char] (10) NULL,
			[LocAisle]			[char] (10) NULL,
			[ConsigneeKey]		[char] (15) NULL,
			[RETAILSKU]			[char] (20) NULL ) 

   IF (@n_continue = 1 OR @n_continue=2) 
   BEGIN
	  IF ISNULL(dbo.fnc_RTRIM(@c_type),'') = 'R' 
	  BEGIN
      -- Print from XDOCK ASN screen - XDOCK, having ExternPOKey
		 INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku,
												   Qty, Packkey, UOM, PickSlipNo)
         SELECT DISTINCT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber,  
            PD.Storerkey, PD.Sku, PD.Qty, PD.Packkey, PD.UOM, PD.PickSlipNo
         FROM  ReceiptDetail RD (NOLOCK)
         INNER JOIN OrderDetail OD (NOLOCK) ON (RD.ExternReceiptKey = OD.ExternPOKey)
         INNER JOIN PickDetail PD (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND
                                               PD.OrderLineNumber = OD.OrderLineNumber)
         INNER JOIN SKU SKU (NOLOCK) ON (OD.StorerKey = SKU.StorerKey AND
                                         OD.SKU = SKU.SKU)
         WHERE RD.ExternReceiptKey = @c_refkey
         AND   PD.Status < '9'
         AND   PD.UOM = '2'
         AND   PD.CaseID = ''
	  END
	  ELSE -- 'L'
	  BEGIN
         -- Print from LoadPlan - Indent stock, no ExternPOKey
		 INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku,
												   Qty, Packkey, UOM, PickSlipNo)
         SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber,  
            PD.Storerkey, PD.Sku, PD.Qty, PD.Packkey, PD.UOM, PD.PickSlipNo
         FROM  LoadPlanDetail LPD (NOLOCK)
         INNER JOIN PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
         INNER JOIN Orders OH (NOLOCK) ON (PD.OrderKey = OH.OrderKey)
         INNER JOIN OrderDetail OD (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND
                                                PD.OrderLineNumber = OD.OrderLineNumber AND
                                                OD.LoadKey = LPD.LoadKey)
         INNER JOIN SKU SKU (NOLOCK) ON (OD.StorerKey = SKU.StorerKey AND
                                         OD.SKU = SKU.SKU)
         WHERE LPD.Loadkey = @c_refkey
         AND   PD.Status < '9'
         AND   PD.UOM = '2'
         AND   PD.CaseID = ''
	  END

      IF @b_debug = 1
      BEGIN
         SELECT @c_refkey '@c_refkey', @c_type '@c_type'
         SELECT * FROM #TEMPPICKDETAIL
      END         

      WHILE @@TRANCOUNT > @n_starttcnt
         COMMIT TRAN

      IF (SELECT COUNT(1) FROM #TEMPPICKDETAIL) > 0 
      BEGIN
         -- BEGIN TRAN
        
         DECLARE PD_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PickDetailKey, StorerKey, Sku, PackKey, Qty, 
               OrderKey, OrderLineNumber, PickSlipNo
            FROM   #TEMPPICKDETAIL
            ORDER BY PickDetailKey
	
      	OPEN PD_CUR
      
      	FETCH NEXT FROM PD_CUR INTO @c_PickDetailKey, @c_StorerKey, @c_Sku, @c_PackKey, @n_Qty,
                                 @c_OrderKey, @c_OrderLineNumber, @c_PickSlipNo                                      
      
      	WHILE @@FETCH_STATUS <> -1
      	BEGIN
            BEGIN TRAN 

            SELECT @n_CaseCnt = 0
            SELECT @n_NoOfCases = 0, @c_CaseID = '', @c_NewPickDetailKey = ''
     
            -- Get CaseCnt and decide how many caseid needed
            SELECT @n_CaseCnt = CaseCnt FROM PACK (NOLOCK) WHERE PackKey = @c_PackKey 
            
            IF @b_debug = 1
            BEGIN
               SELECT @c_PickDetailKey '@c_PickDetailKey', @c_Sku '@c_Sku', @c_StorerKey '@c_StorerKey', 
                  @n_CaseCnt '@n_CaseCnt', @c_PackKey '@c_PackKey', @n_Qty '@n_Qty'
            END  

            IF @n_CaseCnt <= 0 -- Do not proceed
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63100
            	SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': CaseCnt for Packkey ' + @c_PackKey + ' is zero. ' + 
                                  ' (nsp_PrintCaseLabel_WTC_TH)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)),'') + ' ) '
               GOTO EXIT_SP
            END 
            ELSE -- if @n_CaseCnt > 0 then proceed
            BEGIN
               -- Get No. of Cases needed, ie. how many caseid needed
               SELECT @n_NoOfCases = @n_Qty / @n_CaseCnt

               IF @b_debug = 1
               BEGIN
                  SELECT @n_NoOfCases 'Batch - @n_NoOfCases'
               END 

               -- Generate CaseID               
               EXEC nspg_getkey
                  'CASEID',
                  9,
                  @c_CaseID     OUTPUT,
                  @b_success    OUTPUT,
                  @n_err        OUTPUT,
                  @c_errmsg     OUTPUT,
                  0,
                  @n_NoOfCases -- BATCH

               IF @b_success <> 1 
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63101   
               	  SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Generate CaseID Failed. ' + 
                                     ' (nsp_PrintCaseLabel_WTC_TH)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)),'') + ' ) '
                  GOTO EXIT_SP
               END
                     
               IF @b_debug = 1
               BEGIN
                  SELECT @c_CaseID 'Generated new @c_CaseID', @n_NoOfCases 'Batch - @n_NoOfCases'
               END 

               SELECT @n_Cnt = 1, @c_TempCaseID = '', @c_NewCaseID = ''
               WHILE @n_Cnt <= @n_NoOfCases
               BEGIN
                  -- For 1st caseid among all, or only 1 caseid
                  IF ( @n_Cnt = 1 OR @n_NoOfCases = 1 )
                  BEGIN
                     SELECT @c_NewCaseID = 'C' + @c_CaseID 

                     IF @b_debug = 1
                     BEGIN
                        SELECT @c_NewCaseID '@c_NewCaseID if @n_Cnt = 1 OR @n_NoOfCases = 1'
                     END 
                          
                     -- Upadate PickDetail with trafficcop = NULL (not invoke trigger)
                     UPDATE PICKDETAIL WITH (ROWLOCK)
                     SET   TrafficCop = NULL,
                           CaseID = @c_NewCaseID,
                           Qty = @n_CaseCnt
                     WHERE PickDetailKey = @c_PickDetailKey
                     AND   Status < '9'
                     AND   CaseID = ''
                     
                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63102   
                     	SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update PickDetail Failed. ' + 
                                           ' (nsp_PrintCaseLabel_WTC_TH)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)),'') + ' ) '
                        GOTO EXIT_SP
                     END
                  END
                  ELSE -- other than 1st case
                  BEGIN
                     SELECT @n_CaseID = CONVERT(int, @c_CaseID)
                     SELECT @n_CaseID = @n_CaseID + (@n_Cnt - 1)
                     SELECT @c_NewCaseID = 'C'+ RIGHT (REPLICATE('0',10) + ISNULL(dbo.fnc_RTRIM(CONVERT (char(10), @n_CaseID)),''),9)

                     -- Generate PickDetailKey
                     EXEC nspg_getkey
                        'PICKDETAILKEY',
                        10,
                        @c_NewPickDetailKey  OUTPUT ,
                        @b_success     OUTPUT,
                        @n_err         OUTPUT,
                        @c_errmsg      OUTPUT 
                     
                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63103   
                     	SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Generate PickDetailKey Failed. ' + 
                                           ' (nsp_PrintCaseLabel_WTC_TH)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)),'') + ' ) '
                        GOTO EXIT_SP
                     END                     

                     IF @b_debug = 2
                     BEGIN
                        select @n_CaseID '@n_CaseID'
                        SELECT @n_Cnt '@n_Cnt', @c_NewCaseID '@c_NewCaseID', @c_NewPickDetailKey '@c_NewPickDetailKey'
                     END

                     -- Insert new PickDetail with OptimizeCop = NULL (not invoke trigger)
                     INSERT INTO PICKDETAIL ( PickDetailKey, CaseID, PickHeaderkey, OrderKey, OrderLineNumber, 
                           Storerkey, Sku, PackKey, Lot, Loc, ID, UOM, UOMQty, Qty, PickMethod, Cartongroup, CartonType,  
                           DoReplenish, ReplenishZone, DoCartonize, PickSlipNo, Status, TrafficCop, OptimizeCop)
                     SELECT @c_NewPickDetailKey, @c_NewCaseID, PickHeaderkey, OrderKey, OrderLineNumber, 
                           Storerkey, Sku, PackKey, Lot, Loc, ID, UOM, UOMQty, @n_CaseCnt, PickMethod, Cartongroup, CartonType,  
                           DoReplenish, ReplenishZone, DoCartonize, PickSlipNo, Status, NULL, '9'
                     FROM  PickDetail (NOLOCK)  
                     WHERE PickDetailKey = @c_PickDetailKey
                     AND   Status < '9'

                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63104   
                     	SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert PickDetail Failed. ' + 
                                           ' (nsp_PrintCaseLabel_WTC_TH)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)),'') + ' ) '
                        GOTO EXIT_SP
                     END

                     -- Insert RefKeyLookup
         				INSERT INTO RefKeyLookup (OrderKey, OrderLinenumber, PickSlipNo, PickDetailKey)
         				VALUES (@c_OrderKey, @c_OrderLineNumber, @c_PickSlipNo, @c_NewPickDetailKey) 

                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63105   
                     	SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert RefKeyLookup Failed. ' + 
                                           ' (nsp_PrintCaseLabel_WTC_TH)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)),'') + ' ) '
                        GOTO EXIT_SP
                     END

                  END

                  IF @b_debug = 1
                  BEGIN
                     SELECT * FROM PickDetail (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey
                     SELECT * FROM PickDetail (NOLOCK) WHERE PickDetailKey = @c_NewPickDetailKey
                  END
               
                  SELECT @n_Cnt = @n_Cnt + 1 -- Get Next Case
               END -- End of WHILE @n_Cnt <= @n_NoOfCases
            
            END -- IF @n_CaseCnt > 0
      
            -- Commit by PickDetailKey level
            WHILE @@TRANCOUNT > @n_starttcnt 
               COMMIT TRAN

		      FETCH NEXT FROM PD_CUR INTO @c_PickDetailKey, @c_StorerKey, @c_Sku, @c_PackKey, @n_Qty,
                                    @c_OrderKey, @c_OrderLineNumber, @c_PickSlipNo			
	      END -- @@FETCH_STATUS <> -1

	      CLOSE PD_CUR
	      DEALLOCATE PD_CUR
                
         GOTO PRINT_CASELABEL

      END -- End of IF (SELECT COUNT(1) FROM #TEMPPICKDETAIL) > 0 (Having CaseId is blank)
      ELSE
      BEGIN
         -- Print Case Label (used for reprint)
         GOTO PRINT_CASELABEL
      END

      -- SOS47221 - Start
      -- Print Case Label
   	  PRINT_CASELABEL:

		SELECT @c_ResXDockLane   = '',
		   @c_ResSellerName      = '',
		   @c_ResExternPOKey     = '',
		   @c_ResSku             = '',
		   @c_ResSkuDescr	     = '',
		   @c_ResQty             = 0,		
		   @c_ResPickSlipNo      = '',
		   @c_ResPrevPickSlipNo  = '',
           @c_ResCaseID          = '',
		   -- (Vanessa01)
		   @c_ResPutAwayZone     = '',
		   @c_ResLogicalLocation = '',
		   @c_ResLoc			 = '',
		   @c_ResLocAisle	     = '',
		   @c_ResConsigneeKey    = '',
		   @c_ResRETAILSKU	     = ''
		   -- (Vanessa01)

      IF ISNULL(dbo.fnc_RTRIM(@c_type),'') = 'R' 
   	  BEGIN 
	      DECLARE RESULT_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR         
            -- XDOCK stock, RD.ExternReceiptKey = OD.ExternPOKey = PO.ExternPOKey
            -- Remarked by MaryVong on 28-Feb-2006
            -- SELECT DISTINCT OH.ConsigneeKey, PO.SellerName, OD.ExternPOKey, PD.Sku, SKU.Descr, PD.Qty,
            SELECT DISTINCT StorerSODefault.XDockLane, PO.SellerName, OD.ExternPOKey, PD.Sku, SKU.Descr, PD.Qty,
               PD.PickSlipNo, PD.CaseID, 
			   LOC.PutAwayZone, LOC.LogicalLocation, LOC.Loc, LOC.LocAisle, OH.ConsigneeKey, SKU.RETAILSKU  -- (Vanessa01)
            FROM  ReceiptDetail RD (NOLOCK)
            INNER JOIN OrderDetail OD (NOLOCK) ON (RD.ExternReceiptKey = OD.ExternPOKey)
            INNER JOIN Orders OH (NOLOCK) ON (OH.OrderKey = OD.OrderKey)
            INNER JOIN PickDetail PD (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND
                                                  PD.OrderLineNumber = OD.OrderLineNumber)
            INNER JOIN PO PO (NOLOCK) ON (PO.ExternPOKey = RD.ExternReceiptKey)
            INNER JOIN SKU SKU (NOLOCK) ON (OD.StorerKey = SKU.StorerKey AND
                                            OD.SKU = SKU.SKU)
			INNER JOIN LOC LOC (NOLOCK) ON (PD.LOC=LOC.LOC)  -- (Vanessa01)
            LEFT OUTER JOIN Storer Storer (NOLOCK) ON (Storer.StorerKey = OH.ConsigneeKey)
            LEFT OUTER JOIN StorerSODefault StorerSODefault (NOLOCK) 
                                         ON (StorerSODefault.StorerKey = Storer.StorerKey)
            WHERE RD.ExternReceiptKey = @c_refkey
            AND   PD.Status < '9'
            AND   PD.UOM = '2'
            AND   PD.CaseID <> ''
            Order by LOC.PutAwayZone, LOC.LogicalLocation, LOC.Loc, PD.Sku  -- (Vanessa01)
      END
      ELSE -- 'L'
      BEGIN
	      DECLARE RESULT_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         -- Indent stock - no ExternPOKey and SellerName printed
         -- Remarked by MaryVong on 28-Feb-2006
         -- SELECT OH.ConsigneeKey, '' as SellerName, '' as ExternPOKey, PD.Sku, SKU.Descr, PD.Qty, 
         SELECT StorerSODefault.XDockLane, '' as SellerName, '' as ExternPOKey, PD.Sku, SKU.Descr, PD.Qty, 
            PD.PickSlipNo, PD.CaseID, 
			LOC.PutAwayZone, LOC.LogicalLocation, LOC.Loc, LOC.LocAisle, OH.ConsigneeKey, SKU.RETAILSKU  -- (Vanessa01) 
         FROM  LoadPlanDetail LPD (NOLOCK)
         INNER JOIN PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
         INNER JOIN Orders OH (NOLOCK) ON (PD.OrderKey = OH.OrderKey)
         INNER JOIN OrderDetail OD (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND
                                                PD.OrderLineNumber = OD.OrderLineNumber AND
                                                OD.LoadKey = LPD.LoadKey)
         INNER JOIN SKU SKU (NOLOCK) ON (OD.StorerKey = SKU.StorerKey AND
                                         OD.SKU = SKU.SKU)
		 INNER JOIN LOC LOC (NOLOCK) ON (PD.LOC=LOC.LOC)  -- (Vanessa01)
         LEFT OUTER JOIN Storer Storer (NOLOCK) ON (Storer.StorerKey = OH.ConsigneeKey)            
         LEFT OUTER JOIN StorerSODefault StorerSODefault (NOLOCK) 
                                      ON (StorerSODefault.StorerKey = Storer.StorerKey)
         WHERE LPD.Loadkey = @c_refkey
         AND   PD.Status < '9'
         AND   PD.UOM = '2'
         AND   PD.CaseID <> ''
         Order by LOC.PutAwayZone, LOC.LogicalLocation, LOC.Loc, PD.Sku  -- (Vanessa01)
      END    

   	  OPEN RESULT_CUR
   
   	  FETCH NEXT FROM RESULT_CUR INTO @c_ResXDockLane, @c_ResSellerName, @c_ResExternPOKey, @c_ResSku, @c_ResSkuDescr,
                                      @c_ResQty, @c_ResPickSlipNo, @c_ResCaseID,
									  @c_ResPutAwayZone, @c_ResLogicalLocation, @c_ResLoc, @c_ResLocAisle, @c_ResConsigneeKey, @c_ResRETAILSKU  -- (Vanessa01)
   
      SELECT @c_ResPrevPickSlipNo = @c_ResPickSlipNo

   	  WHILE @@FETCH_STATUS <> -1
   	  BEGIN

         INSERT INTO #TEMPRESULT 
            (XDockLane, SellerName, ExternPOKey, Sku, SkuDescr, 
             Qty, PickSlipNo, CaseID, Loc, LocAisle, ConsigneeKey, RETAILSKU)  -- (Vanessa01)
         VALUES 
            (@c_ResXDockLane, @c_ResSellerName, @c_ResExternPOKey, @c_ResSku, @c_ResSkuDescr,
             @c_ResQty, @c_ResPickSlipNo, @c_ResCaseID, @c_ResLoc, @c_ResLocAisle, @c_ResConsigneeKey, @c_ResRETAILSKU) -- (Vanessa01)

         -- Assign previous pickslipno var
         SELECT @c_ResPrevPickSlipNo = @c_ResPickSlipNo
         
   	     FETCH NEXT FROM RESULT_CUR INTO @c_ResXDockLane, @c_ResSellerName, @c_ResExternPOKey, @c_ResSku, @c_ResSkuDescr, 
                                         @c_ResQty, @c_ResPickSlipNo, @c_ResCaseID,
									     @c_ResPutAwayZone, @c_ResLogicalLocation, @c_ResLoc, @c_ResLocAisle, @c_ResConsigneeKey, @c_ResRETAILSKU  -- (Vanessa01)

         IF @b_debug = 1
         BEGIN
            SELECT @c_ResPrevPickSlipNo '@c_ResPrevPickSlipNo', @c_ResPickSlipNo '@c_ResPickSlipNo'
         END

         IF @c_ResPrevPickSlipNo <> @c_ResPickSlipNo
         BEGIN
            -- Insert blank record (with XDockLane = '*')
            INSERT INTO #TEMPRESULT (XDockLane, SellerName, ExternPOKey, Sku, SkuDescr, Qty, PickSlipNo, CaseID, Loc, LocAisle, ConsigneeKey, RETAILSKU)  -- (Vanessa01)
            VALUES ('*', '', '', '', '', 0, '', '', '', '', '', '') -- (Vanessa01)           
         END

   	  END -- @@FETCH_STATUS <> -1
   
   	  CLOSE RESULT_CUR
   	  DEALLOCATE RESULT_CUR

      -- Extract data (sort by rowid)
	  SELECT XDockLane, 
           SellerName, 
           ExternPOKey,  
		   Sku,  
		   SkuDescr,           
		   Qty,		
		   PickSlipNo,
           CaseID, 
		   -- (Vanessa01)
           Loc,
		   LocAisle, 
		   ConsigneeKey, 
		   RETAILSKU 
		   -- (Vanessa01)
      FROM #TEMPRESULT
      ORDER BY RowId

      -- End of SOS47221 

      EXIT_SP: 
      IF @n_continue = 3
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         ROLLBACK TRAN
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_PrintCaseLabel_WTC_TH'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
      ELSE
      BEGIN
         /* Error Did Not Occur , Return Normally */
         WHILE @@TRANCOUNT > @n_starttcnt
            COMMIT TRAN
         RETURN
      END

   END -- IF (@n_continue = 1 OR @n_continue=2) 

   DROP TABLE #TEMPPICKDETAIL
   DROP TABLE #TEMPRESULT

END

GO