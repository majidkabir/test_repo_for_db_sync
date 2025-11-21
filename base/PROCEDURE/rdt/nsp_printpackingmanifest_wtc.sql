SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  rdt.nsp_PrintPackingManifest_WTC                   */
/* Creation Date: 06-Feb-2006                           						*/
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                          			*/
/*                                                                      */
/* Purpose:  Create to Packing Manifest (Pallet/Tote) 					   */
/*           SOS45053 WTCPH - Print Packing Manifest                    */
/*           Notes: 1) This is used by a stand alone application named  */
/*                     'WTC - Packing Manifest'                         */
/*                  2) Provide Print Current and Reprint options        */
/*                  3) Packing Manifest will be printed after user end- */
/*                     scan one pallet or tote (thru RDT)               */
/*                  4) User can reprint by entering sufficient params   */
/*                  5) Use type to differentiate:                       */
/*                     i)   Pallet -> Case is 'C'                       */
/*                     ii)  Pallet -> Store-Addressed is 'S'            */
/*                     iii) Tote is 'T'                                 */
/*                  6) Prefix for :                                     */
/*                     i)   Pallet -> Case = 'C'                        */
/*                     ii)  Pallet -> Store-Addressed = 'S','B', etc    */
/*                     iii) Tote = 'T','V','K', etc                     */
/*                                                                      */
/* Input Parameters:  @c_storerkey,    - storerkey							   */
/*							 @c_workstation,  - workstation to do scanning     */
/*                    @c_consigneekey, - store which stock shipped to   */
/*                    @c_refno,        - can be Pallet ID or Tote #     */
/*                    @c_scandate      - scanning date                  */
/*                                                                      */
/* Output Parameters: report                                            */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  dw = r_dw_packingmanifest_wtc             					*/
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 07-Mar-2006  MaryVong        SOS47110 Set ExternPOKey in temp table  */
/*                              to allow NULL                           */
/* 10-Mar-2006  MaryVong        SOS47186 Modification on:               */            
/*                              1) Use Type to differentiate 3 category */
/*                                 of CaseIDs                           */
/*                              2) Print Pallet ID where Type = 'C' or  */
/*                                 'S', print Tote# where Type = 'T'    */
/* 15-Mar-2006  MaryVong        SOS47520 Using cursor to handle         */
/*                              Type = 'S'                              */
/* 23-Mar-2006  MaryVong        SOS47223 :                              */
/*                              1) Avoid qty double-up for same Tote#   */
/*                              2) Cater for splitted orderlines for    */
/*                                 Tote                                 */
/* 10-May-2006  MaryVong        SOS50521 Add 3 fields: RefNo1,RefNo2 &  */
/*                              RefNo3                                  */
/*	28-Nov-2006  MaryVong        Show GroupID for debugging purpose		*/
/*	10-Oct-2008  Vanessa         SOS#118607 Solved Duplicate data at     */
/*                              Type=T by add "and PD.DropID =AU.Rowref"*/
/*                               -- (Vanessa01)                         */
/* 17-Oct-2008	 YTWan		1.2  SOS#124215 Add MfgLot & Expiry date     */
/*                              (YTWan01)                               */
/************************************************************************/

CREATE PROC [RDT].[nsp_PrintPackingManifest_WTC] (
   @c_storerkey      NVARCHAR(15), 
   @c_workstation    NVARCHAR(15),
   @c_consigneekey   NVARCHAR(15),
   @c_refno          NVARCHAR(18),
   @c_scandate       NVARCHAR(20) -- not confirm yet
)   
AS
BEGIN
	SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE
	   @n_continue		      int,
	   @n_err			      int,
	   @c_errmsg		      NVARCHAR(255),
	   @b_success		      int,
		@n_starttcnt         int,
      @b_debug             int

   DECLARE 
      @c_ReprintFlag       NVARCHAR(1), -- Y/N 
      @dt_StartDate        datetime,
      @dt_EndDate          datetime,
      @n_UniqueGroupID     int,
      @n_GroupID           int,
      @c_PalletID          NVARCHAR(18),
      @c_CaseID            NVARCHAR(18),
      @c_Type              NVARCHAR(1),
      @c_Receiptkey        NVARCHAR(10),
      @c_OrderKey          NVARCHAR(10),
      @c_ExternPOKey       NVARCHAR(20),

      @c_IDS_Company       NVARCHAR(45),
      @c_IDS_Address1      NVARCHAR(45),  
      @c_IDS_Address2      NVARCHAR(45),
      @c_IDS_Address3      NVARCHAR(45),
      @c_IDS_Address4      NVARCHAR(45),
      @c_IDS_City          NVARCHAR(45),
      @c_IDS_Country       NVARCHAR(30),
      @c_AUConsigneeKey	 NVARCHAR(15),
      @c_C_Company         NVARCHAR(45),
      @c_C_Address1        NVARCHAR(45),
      @c_C_Address2        NVARCHAR(45),
      @c_C_Address3        NVARCHAR(45),
      @c_C_Address4        NVARCHAR(45),
      @c_C_City            NVARCHAR(45),
      @c_C_Country         NVARCHAR(30),
      @c_Sku               NVARCHAR(20),
      @c_SkuDescr          NVARCHAR(60),
      @n_QtyCases          int,
      @n_QtyEaches         int

   DECLARE   
      @c_ToteOrderKey   NVARCHAR(10),
      @c_TotePOKey      NVARCHAR(20),
      @c_ToteSku        NVARCHAR(20),
      @c_ToteSkuDescr   NVARCHAR(60),
      @c_ToteRefNo1     NVARCHAR(20), -- SOS50521
      @c_ToteRefNo2     NVARCHAR(20), -- SOS50521
      @c_ToteRefNo3     NVARCHAR(20), -- SOS50521      
      @n_ToteRowID      int,
      @c_SplitLineSku   NVARCHAR(20)

   SELECT 
      @b_debug     = 0,
      @n_continue  = 1,
      @n_starttcnt = @@TRANCOUNT

   SELECT 
      @c_ReprintFlag    = 'N',
      --@n_UniqueGroupID  = 0,
      @n_GroupID        = 0,
      @c_PalletID       = '',
      @c_CaseID         = '',
      @c_Type           = '',
      @c_Receiptkey     = '',
      @c_OrderKey       = '',
      @c_ExternPOKey    = '',

      @c_IDS_Company    = '',
      @c_IDS_Address1   = '',
      @c_IDS_Address2   = '',
      @c_IDS_Address3   = '',
      @c_IDS_Address4   = '',
      @c_IDS_City       = '',
      @c_IDS_Country    = '',
      @c_AUConsigneeKey = '',
      @c_C_Company      = '',
      @c_C_Address1     = '',
      @c_C_Address2     = '',
      @c_C_Address3     = '',
      @c_C_Address4     = '',
      @c_C_City         = '',
      @c_C_Country      = '',
      @c_SKU            = '',
      @c_SkuDescr       = '',
      @n_QtyCases       = 0,
      @n_QtyEaches      = 0

   /* @TEMPDATA */
   DECLARE @TEMPDATA TABLE (
      RowID             int IDENTITY (1, 1),
      GroupID           int,
      PalletID          NVARCHAR(18)   NULL,  
      CaseID            NVARCHAR(18)   NULL,
      Type              NVARCHAR(1)    NULL
      )

   /* @TEMPPACK */
   DECLARE @TEMPPACK TABLE (
      StorerKey         NVARCHAR(15),
      WorkStation		   NVARCHAR(15),
      OrderKey			 NVARCHAR(10)   NULL,   -- SOS47110 
      ExternPOKey       NVARCHAR(20)   NULL, 
      IDS_Company       NVARCHAR(45)   NULL,
      IDS_Address1      NVARCHAR(45)   NULL,  
      IDS_Address2      NVARCHAR(45)   NULL,
      IDS_Address3      NVARCHAR(45)   NULL,
      IDS_Address4      NVARCHAR(45)   NULL,
      IDS_City          NVARCHAR(45)   NULL,
      IDS_Country       NVARCHAR(30)   NULL,
      ConsigneeKey	 NVARCHAR(15),
      C_Company         NVARCHAR(45)   NULL,
      C_Address1        NVARCHAR(45)   NULL,  
      C_Address2        NVARCHAR(45)   NULL,
      C_Address3        NVARCHAR(45)   NULL,
      C_Address4        NVARCHAR(45)   NULL,
      C_City            NVARCHAR(45)   NULL,
      C_Country         NVARCHAR(30)   NULL,
      Sku				 NVARCHAR(20)   NULL,  
      SkuDescr          NVARCHAR(60)   NULL,
      QtyCases				int,	
      QtyEaches         int,
      GroupID           int,
      PalletID          NVARCHAR(18)   NULL, -- SOS47186         
      CaseID            NVARCHAR(18)   NULL, -- SOS47186
      ReprintFlag       NVARCHAR(1),
      Type              NVARCHAR(1)    NULL, -- SOS47186
      RefNo1            NVARCHAR(20)   NULL, -- SOS50521
      RefNo2            NVARCHAR(20)   NULL, -- SOS50521
      RefNo3            NVARCHAR(20)   NULL, -- SOS50521
      Lottable02        NVARCHAR(18) NULL,												-- YTWan01
		Lottable04        datetime    NULL												-- YTWan01
      )

   /* @TEMPTOTE */
   DECLARE @TEMPTOTE TABLE (
      TTRowID       int IDENTITY (1,1),
      CaseID        NVARCHAR(18)   NULL,
      Sku           NVARCHAR(20)   NULL,
      SkuDescr      NVARCHAR(60)   NULL,
      OrderKey      NVARCHAR(10)   NULL,
      ExternPOKey   NVARCHAR(20)   NULL,
      PDQty         int,
      AuditQty      int,
      PackedQty     int,
      RefNo1        NVARCHAR(20) NULL, -- SOS50521
      RefNo2        NVARCHAR(20) NULL, -- SOS50521
      RefNo3        NVARCHAR(20) NULL, -- SOS50521
      Lottable02        NVARCHAR(18) NULL,												-- YTWan01
		Lottable04        datetime    NULL												-- YTWan01
      )
   
   /* @TEMPTOTE_UNMATCH */
   DECLARE @TEMPTOTE_UNMATCH TABLE (
      UMRowID   int,
      UMSku     NVARCHAR(20)
      )

	DECLARE @c_lottable02 NVARCHAR(18),													-- YTWan01
			  @c_Lottable04 datetime														-- YTWan01
   /***********************************************************************************
    If NO parameters entered, retrieve all records for the particular workstation, 
    ie. records with status '5' (End Scanned) and update status to '9' after printed;
    Otherwise, retrieve based on provided parameters.
    Notes: StorerKey and WorkStation are captured from INI file
   ************************************************************************************/

   IF (RTRIM(LTRIM(@c_storerkey)) IS NULL OR RTRIM(LTRIM(@c_storerkey)) = '') 
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63101   
   	SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Storerkey is blank. ' + 
                         ' (rdt.nsp_PrintPackingManifest_WTC)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      GOTO EXIT_SP      
   END
   
   IF (RTRIM(LTRIM(@c_workstation)) IS NULL OR RTRIM(LTRIM(@c_workstation)) = '') 
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63102   
   	SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': WorkStation is blank. ' + 
                         ' (rdt.nsp_PrintPackingManifest_WTC)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      GOTO EXIT_SP        
   END         

   /******************************************************************************************
    1) Pallet -> Case :          
       i)   Type = 'C' with prefix as 'C'
       ii)  PD.CaseID = AU.CaseID and PD.SKU = AU.SKU 
    2) Tote : 
       i)   Type = 'T' with prefix as 'T', 'V', 'K', etc.
       ii)  PD.CaseID = AU.CaseID and PD.SKU = AU.SKU
    3) Pallet -> Store-Addressed: 
       i)   Type = 'S' with prefix as 'S', 'B', etc.
       ii)  PD.CaseID <> AU.CaseID and PD.CaseID = '(STORADDR)', or
       iii) AU.CaseID not exists in any table, ie. temporary id
   *******************************************************************************************/

   -->> No parameter entered (first time printing) 
   IF (RTRIM(LTRIM(@c_consigneekey)) IS NULL OR RTRIM(LTRIM(@c_consigneekey)) = '') AND
      (RTRIM(LTRIM(@c_refno)) IS NULL OR RTRIM(LTRIM(@c_refno)) = '') AND
      (RTRIM(LTRIM(@c_scandate)) IS NULL OR RTRIM(LTRIM(@c_scandate)) = '')
   BEGIN
      SELECT @c_ReprintFlag = 'N'
   END      
   ELSE
   BEGIN
      SELECT @c_ReprintFlag = 'Y'
      -- Get start and end date for reprint
      SELECT @dt_StartDate = CONVERT(datetime, @c_scandate)  
      SELECT @dt_EndDate   = DATEADD (DAY, 1, CONVERT(datetime, @c_scandate))
   END


   /************************************/
   /* Insert data into @TEMPDATA table */
   /************************************/
   IF @c_ReprintFlag = 'N' 
   BEGIN
      INSERT INTO @TEMPDATA
         (GroupID, PalletID, CaseID, Type)
      SELECT 
         GroupID,
         PalletID,
         CaseID,
         Type
      FROM  RDT.RDTCsAudit AU WITH (NOLOCK)
      WHERE AU.WorkStation = @c_workstation
      AND   AU.StorerKey = @c_storerkey
      AND   AU.Status = '5'
      GROUP BY            -- Tote will retrieve only 1 row
         GroupID,
         PalletID,
         CaseID,
         Type         
      ORDER BY 
         GroupID 
   END
   ELSE IF @c_ReprintFlag = 'Y'
   BEGIN
      -- Initialize as NULL not zero, prevent to have GroupID=0 for insertion
      SET @n_UniqueGroupID = NULL
            
      -- Get the unique GroupID of the reprint record set
      SELECT TOP 1 
         @n_UniqueGroupID = GroupID 
      FROM RDT.RDTCsAudit AU WITH (NOLOCK)
      WHERE AU.WorkStation = @c_workstation
      AND AU.StorerKey = @c_storerkey
      AND AU.ConsigneeKey = @c_consigneekey
      AND (AU.PalletID = @c_refno OR AU.CaseID = @c_refno)
      AND AU.EditDate BETWEEN @dt_StartDate AND @dt_EndDate
      AND AU.GroupID <> 0   -- Prevent getting bad data (GroupID=0 and Status=9, cause unknown yet)      
      AND AU.Status = '9'

      INSERT INTO @TEMPDATA
         (GroupID, PalletID, CaseID, Type)
      SELECT 
         GroupID,
         PalletID,
         CaseID,
         Type
      FROM  RDT.RDTCsAudit AU WITH (NOLOCK)
      WHERE AU.WorkStation = @c_workstation
      AND   AU.StorerKey = @c_storerkey
      AND   AU.GroupID = @n_UniqueGroupID
      AND   AU.Status = '9'
      GROUP BY            -- Tote will retrieve only 1 row
         GroupID,
         PalletID,
         CaseID,
         Type        

   END

   IF @b_debug = 1
   BEGIN
      SELECT 'Select data from @TEMPDATA'
      SELECT * FROM @TEMPDATA
   END         

   /*******************************************/
   /* End of Insert data into @TEMPDATA table */
   /*******************************************/
 
   /**************************************/
   /* While @TEMPDATA table is not empty */
   /**************************************/
   IF EXISTS (SELECT 1 FROM @TEMPDATA)
   BEGIN
      /********************/
      /* Get general data */
      /********************/
   
      -- Get IDS Address
      SELECT
         @c_IDS_Company   = OG.Company,
         @c_IDS_Address1  = OG.Address1,
         @c_IDS_Address2  = OG.Address2,
         @c_IDS_Address3  = OG.Address3,
         @c_IDS_Address4  = OG.Address4,
         @c_IDS_City      = OG.City,
         @c_IDS_Country   = OG.Country
      FROM dbo.Storer OG WITH (NOLOCK) 
      WHERE OG.StorerKey = 'IDS'

      /************************************************/
      /* Declare cursor and loop thru @TEMPDATA table */
      /************************************************/
   	DECLARE PACKMANI_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT GroupID, PalletID, CaseID, Type
         FROM   @TEMPDATA
   		ORDER BY RowID

   	OPEN PACKMANI_CUR
   
   	FETCH NEXT FROM PACKMANI_CUR INTO @n_GroupID, @c_PalletID, @c_CaseID, @c_Type
   
   	WHILE @@FETCH_STATUS <> -1
   	BEGIN

         /*************************/
         /* Get Consignee Address */
         /*************************/
         SELECT TOP 1 
            @c_AUConsigneeKey = AU.ConsigneeKey
         FROM RDT.RDTCsAudit AU WITH (NOLOCK)
         WHERE AU.WorkStation = @c_workstation
         AND   AU.StorerKey = @c_storerkey
         AND   AU.GroupID = @n_GroupID

         -- Assumption:
         -- All orders having same consignee address as storer
         SELECT
            @c_C_Company     = ST.Company,
            @c_C_Address1    = ST.Address1,
            @c_C_Address2    = ST.Address2,
            @c_C_Address3    = ST.Address3,
            @c_C_Address4    = ST.Address4,
            @c_C_City        = ST.City,
            @c_C_Country     = ST.Country 
         FROM dbo.Storer ST WITH (NOLOCK)
         WHERE ST.StorerKey = @c_AUConsigneeKey
         

         /**************/
         /* Type = 'S' */
         /**************/
         IF @c_Type = 'S'
         BEGIN
            SELECT @n_QtyCases  = 1
            SELECT @n_QtyEaches = 0
            SELECT @c_SKU       = ''
            SELECT @c_SKUDescr  = @c_CaseID

            IF SUBSTRING(@c_CaseID,1,1) = 'S' -- 'S' + ASN# + 3 digits running number
            BEGIN
               SELECT @c_Receiptkey = SUBSTRING(@c_CaseID,2,10)
               -- Assumption: 
               -- Receipt.ExternReceiptKey always equal to ReceiptDetail.ExternPOKey
               SELECT @c_ExternPOKey = ISNULL(RH.ExternReceiptKey, '')
               FROM dbo.Receipt RH WITH (NOLOCK)
               WHERE RH.ReceiptKey = @c_Receiptkey
            END
            ELSE
            BEGIN
               SELECT @c_ExternPOKey = ''
            END
            
            /*******************************/
            /* Insert into @TEMPPACK table */
            /*******************************/
            INSERT INTO @TEMPPACK 
               ( StorerKey,    WorkStation,  OrderKey,     ExternPOKey,
                 IDS_Company,  IDS_Address1, IDS_Address2, IDS_Address3,
                 IDS_Address4, IDS_City,     IDS_Country,  ConsigneeKey, 
                 C_Company,    C_Address1,   C_Address2,   C_Address3,   
                 C_Address4,   C_City,       C_Country,    Sku,          
                 SkuDescr,     QtyCases,     QtyEaches,    GroupID,      
                 PalletID,     CaseID,       ReprintFlag,  Type
               )
            VALUES  
               ( @c_storerkey,      @c_workstation,  @c_OrderKey,     @c_ExternPOKey,
                 @c_IDS_Company,    @c_IDS_Address1, @c_IDS_Address2, @c_IDS_Address3,
                 @c_IDS_Address4,   @c_IDS_City,     @c_IDS_Country,  @c_AUConsigneeKey, 
                 @c_C_Company,      @c_C_Address1,   @c_C_Address2,   @c_C_Address3,     
                 @c_C_Address4,     @c_C_City,       @c_C_Country,    @c_Sku,            
                 @c_SkuDescr,       @n_QtyCases,     @n_QtyEaches,    @n_GroupID, 
                 @c_PalletID,       @c_CaseID,       @c_ReprintFlag,  @c_Type
               )
         END

         /**************/
         /* Type = 'C' */
         /**************/
         ELSE IF @c_Type = 'C'
         BEGIN
            SELECT @n_QtyCases  = 1
            SELECT @n_QtyEaches = 0

            SELECT 
               @c_OrderKey       = OH.OrderKey,
               @c_ExternPOKey    = OD.ExternPOKey,
               @c_Sku            = AU.SKU, 
               @c_SkuDescr       = AU.Descr,
					@c_lottable02     = LA.Lottable02,										-- YTWan01
			      @c_Lottable04     = LA.Lottable04										-- YTWan01
            FROM  RDT.RDTCsAudit AU WITH (NOLOCK)
            LEFT OUTER JOIN dbo.PickDetail PD WITH (NOLOCK)
               ON ( PD.CaseID = AU.CaseID AND PD.StorerKey = AU.StorerKey AND PD.SKU = AU.SKU 
              AND   PD.DropID = AU.Rowref ) 												-- YTWan01
            LEFT OUTER JOIN dbo.OrderDetail OD WITH (NOLOCK) 
               ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
            LEFT OUTER JOIN dbo.Orders OH WITH (NOLOCK)
               ON (OH.OrderKey = OD.OrderKey)    
				LEFT OUTER JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK)  		-- YTWan01
					ON (LA.Lot = PD.Lot)   														-- YTWan01
            WHERE AU.WorkStation = @c_workstation	
            AND   AU.StorerKey = @c_storerkey
            AND   AU.GroupID = @n_GroupID
            AND   AU.PalletID = @c_PalletID
            AND   AU.CaseID = @c_CaseID
            AND   AU.Type = 'C'
            --AND   (OH.Status < '9' OR OH.Status IS NULL)
            AND   (PD.Status < '9' OR PD.Status IS NULL)

            /*******************************/
            /* Insert into @TEMPPACK table */
            /*******************************/
            INSERT INTO @TEMPPACK 
               ( StorerKey,    WorkStation,  OrderKey,     ExternPOKey,
                 IDS_Company,  IDS_Address1, IDS_Address2, IDS_Address3,
                 IDS_Address4, IDS_City,     IDS_Country,  ConsigneeKey, 
                 C_Company,    C_Address1,   C_Address2,   C_Address3,   
                 C_Address4,   C_City,       C_Country,    Sku,          
                 SkuDescr,     QtyCases,     QtyEaches,    GroupID,      
                 PalletID,     CaseID,       ReprintFlag,  Type,
					  Lottable02,	 Lottable04													-- YTWan01
               )
            VALUES  
               ( @c_storerkey,      @c_workstation,  @c_OrderKey,     @c_ExternPOKey,
                 @c_IDS_Company,    @c_IDS_Address1, @c_IDS_Address2, @c_IDS_Address3,
                 @c_IDS_Address4,   @c_IDS_City,     @c_IDS_Country,  @c_AUConsigneeKey, 
                 @c_C_Company,      @c_C_Address1,   @c_C_Address2,   @c_C_Address3,     
                 @c_C_Address4,     @c_C_City,       @c_C_Country,    @c_Sku,            
                 @c_SkuDescr,       @n_QtyCases,     @n_QtyEaches,    @n_GroupID, 
                 @c_PalletID,       @c_CaseID,       @c_ReprintFlag,  @c_Type,
					  @c_lottable02,     @c_lottable04										-- YTWan01
               )
         END

         /**************/
         /* Type = 'T' */
         /**************/
         ELSE IF @c_Type = 'T'
         BEGIN
            /***********************************************************/
            /* Example of possible data:                               */
            /*                                                         */ 
            /* SKU   PDQty   AuditQty Remarks                          */
            /* ---   -----   -------- -------                          */
            /* Sku1  10      10       - Perfect matching in PickDetail */
            /* Sku2  3       10       - Split line in PickDetail       */
            /* Sku2  7       10       - Split line in PickDetail       */
            /* Sku3  8       10       - Short in PickDetail            */
            /* Sku4  NULL    5        - Not exist in PickDetail        */
            /***********************************************************/

            SELECT @n_QtyCases  = 0
            SELECT @n_QtyEaches = 0

            -- Assumption:
            -- Tote# can only be reused after it was shipped
            INSERT INTO @TEMPTOTE
               (CaseID, Sku, SkuDescr, Orderkey, ExternPOKey, PDQty, AuditQty, PackedQty,
               RefNo1, RefNo2, RefNo3,  -- SOS50521
					Lottable02,	 Lottable04 )													-- YTWan01
            SELECT 
               @c_CaseID,
               AU.SKU, 
               AU.Descr,
               OH.OrderKey,
               OD.ExternPOKey,
               SUM(ISNULL(PD.Qty,0)) AS Qty,										      -- YTWan01
               AU.CountQty_B,
               SUM(ISNULL(PD.Qty,0)) AS PackedQty,										-- YTWan01
               RefNo1, -- SOS50521
               RefNo2, -- SOS50521
               RefNo3, -- SOS50521  
					LA.Lottable02,																	-- YTWan01
			      LA.Lottable04																	-- YTWan01
            FROM  RDT.RDTCsAudit AU WITH (NOLOCK)
            LEFT OUTER JOIN dbo.PickDetail PD WITH (NOLOCK)
               ON ( PD.CaseID = AU.CaseID AND PD.StorerKey = AU.StorerKey AND PD.SKU = AU.SKU and PD.DropID = AU.Rowref) -- (Vanessa01)
            LEFT OUTER JOIN dbo.OrderDetail OD WITH (NOLOCK) 
               ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
            LEFT OUTER JOIN dbo.Orders OH WITH (NOLOCK)
               ON (OH.OrderKey = OD.OrderKey)   
				LEFT OUTER JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK)  		-- YTWan01
					ON (LA.Lot = PD.Lot)   														-- YTWan01      
            WHERE AU.WorkStation = @c_workstation
            AND   AU.StorerKey = @c_storerkey
            AND   AU.GroupID = @n_GroupID
            AND   AU.CaseID = @c_CaseID
            AND   AU.Type = 'T'
            --AND   (OH.Status < '9' OR OH.Status IS NULL)
            AND   (PD.Status < '9' OR PD.Status IS NULL)
				GROUP BY AU.SKU, 																	-- YTWan01
               		AU.Descr,																-- YTWan01
               		OH.OrderKey,															-- YTWan01
               		OD.ExternPOKey,														-- YTWan01
							AU.CountQty_B,  														-- YTWan01
							RefNo1, 																	-- YTWan01
		               RefNo2, 																	-- YTWan01
		               RefNo3, 																	-- YTWan01 
							LA.Lottable02,														   -- YTWan01
			      		LA.Lottable04														   -- YTWan01
            ORDER BY AU.SKU

            IF @b_debug = 1
            BEGIN
               SELECT 'Select data from @TEMPTOTE - Before Update'
               SELECT * FROM @TEMPTOTE
            END   

            /**************************************/
            /* While @TEMPTOTE table is not empty */
            /**************************************/
            IF EXISTS (SELECT 1 FROM @TEMPTOTE)
            BEGIN
               
				
					/*** YTWan01 Remark as Pickdetail.Qty is match with CountQty_B for the particular RowRef/DropiD - START ***/
					/**********************************************************************************************************
               -- Qty matched records 
               -- Update @TEMPTOTE.PackedQty for matched qty
               UPDATE @TEMPTOTE
               SET   PackedQty = PDQty
               FROM  @TEMPTOTE
               WHERE CaseID = @c_CaseID
               AND   SKU IN ( SELECT SKU FROM @TEMPTOTE
                              WHERE CaseID = @c_CaseID
                              AND   PDQty = AuditQty )
               -- End of Qty matched records


               -- Qty unmatched records
               -- Retain Min RowID of unmatched records for further processing
               -- Check thru @TEMPTOTE, might have more than 1 SKU splitted lines in PickDetail
               SELECT @c_SplitLineSku = ''

               WHILE (1=1)
               BEGIN
                  SELECT @c_SplitLineSku = MIN(Sku)
                  FROM  @TEMPTOTE
                  WHERE SKU > @c_SplitLineSku
                  
		            IF @c_SplitLineSku = '' OR @c_SplitLineSku IS NULL
                     BREAK

                  IF EXISTS ( SELECT SKU FROM @TEMPTOTE 
                              WHERE CaseID = @c_CaseID
                              AND   PDQty <> AuditQty
                              AND   SKU = @c_SplitLineSku )
                  BEGIN
                     -- Get Min RowID and split line Sku
                     INSERT INTO @TEMPTOTE_UNMATCH
                        (UMRowID, UMSku)
                     SELECT MIN(TTRowID), @c_SplitLineSku
                     FROM  @TEMPTOTE
                     WHERE CaseID = @c_CaseID  
                     AND   SKU = @c_SplitLineSku

                     IF @b_debug = 1
                     BEGIN
                        SELECT 'Select data from @TEMPTOTE_UNMATCH'
                        SELECT * FROM @TEMPTOTE_UNMATCH                  
                     END   
      
                     -- Remove unmatched records
                     DELETE @TEMPTOTE
                     FROM  @TEMPTOTE_UNMATCH UM
                     WHERE TTRowID <> UM.UMRowID
                     AND   Sku = UM.UMSku
                     AND   PackedQty = 0
                     AND   CaseID = @c_CaseID
                     AND   Sku = @c_SplitLineSku
      
                     -- Update @TEMPTOTE.PackedQty with AuditQty for unmatched qty
                     UPDATE @TEMPTOTE
                     SET   PackedQty = AuditQty
                     FROM  @TEMPTOTE_UNMATCH UM
                     WHERE TTRowID = UM.UMRowID
                     AND   Sku = UM.UMSku
                     AND   CaseID = @c_CaseID
                     AND   Sku = @c_SplitLineSku

                  END
               END
               -- End of Qty Unmatched records 
					*********************************************************************************************************/
				   /*** YTWan01 Remark as Pickdetail.Qty is match with CountQty_B for the particular RowRef/DropiD - END ***/

               IF @b_debug = 1
               BEGIN              
                  SELECT 'Select data from @TEMPTOTE - After Update'
                  SELECT * FROM @TEMPTOTE
               END   

               /* Insert into #TEMPPACK table */
               SELECT
                  @c_ToteOrderKey   = '',
                  @c_TotePOKey      = '',
                  @c_ToteSku        = '',
                  @c_ToteSkuDescr   = '',
                  @c_ToteRefNo1     = '', -- SOS50521
                  @c_ToteRefNo2     = '', -- SOS50521
                  @c_ToteRefNo3     = '', -- SOS50521
                  @n_ToteRowID      = 0

               WHILE (1=1)
               BEGIN
                  SELECT @n_ToteRowID = MIN(TTRowID)
                  FROM @TEMPTOTE
                  WHERE TTRowID > @n_ToteRowID
                  
		            IF @n_ToteRowID = 0 OR @n_ToteRowID IS NULL
                     BREAK
   
                  SELECT
                     @c_ToteOrderKey   = OrderKey,
                     @c_TotePOKey      = ExternPOKey,
                     @c_ToteSku        = Sku,
                     @c_ToteSkuDescr   = SkuDescr,
                     @n_QtyEaches      = PackedQty,
                     @c_ToteRefNo1     = RefNo1,   -- SOS50521
                     @c_ToteRefNo2     = RefNo2,   -- SOS50521
                     @c_ToteRefNo3     = RefNo3,   -- SOS50521
							@c_Lottable02		= Lottable02,									-- YTWan01
							@c_Lottable04		= Lottable04									-- YTWan01
                  FROM @TEMPTOTE
                  WHERE TTRowID = @n_ToteRowID
   
                  /*******************************/
                  /* Insert into @TEMPPACK table */
                  /*******************************/
                  INSERT INTO @TEMPPACK 
                     ( StorerKey,    WorkStation,  OrderKey,     ExternPOKey,
                       IDS_Company,  IDS_Address1, IDS_Address2, IDS_Address3,
                       IDS_Address4, IDS_City,     IDS_Country,  ConsigneeKey, 
                       C_Company,    C_Address1,   C_Address2,   C_Address3,   
                       C_Address4,   C_City,       C_Country,    Sku,          
                       SkuDescr,     QtyCases,     QtyEaches,    GroupID,      
                       PalletID,     CaseID,       ReprintFlag,  Type,
                       RefNo1,       RefNo2,       RefNo3,                     -- SOS50521
							  Lottable02,   Lottable04                                -- YTWan01
                     )
                  VALUES  
                     ( @c_storerkey,         @c_workstation,  @c_ToteOrderKey,  @c_TotePOKey,
                       @c_IDS_Company,       @c_IDS_Address1, @c_IDS_Address2,  @c_IDS_Address3,
                       @c_IDS_Address4,      @c_IDS_City,     @c_IDS_Country,   @c_AUConsigneeKey, 
                       @c_C_Company,         @c_C_Address1,   @c_C_Address2,    @c_C_Address3,     
                       @c_C_Address4,        @c_C_City,       @c_C_Country,     @c_ToteSku,            
                       @c_ToteSkuDescr,      @n_QtyCases,     @n_QtyEaches,     @n_GroupID, 
                       @c_PalletID,          @c_CaseID,       @c_ReprintFlag,   @c_Type,
                       @c_ToteRefNo1,        @c_ToteRefNo2,   @c_ToteRefNo3,                   -- SOS50521  
							  @c_Lottable02,			@c_Lottable04							-- YTWan01                
                     ) 
  
               END -- End of WHILE (1=1)
					DELETE FROM @TEMPTOTE														-- YTWan01  
            END 

         END -- End of Type = 'T'
            
   		FETCH NEXT FROM PACKMANI_CUR INTO @n_GroupID, @c_PalletID, @c_CaseID, @c_Type

   	END -- @@FETCH_STATUS <> -1
   
   	CLOSE PACKMANI_CUR
   	DEALLOCATE PACKMANI_CUR

   END

   -- If first time printing, 
   -- update rdtCsAudit.Status from '5' to '9' after printed
   IF @c_ReprintFlag = 'N'
   BEGIN
      UPDATE RDT.RDTCsAudit WITH (ROWLOCK)
      SET   Status = '9',
            TrafficCop = NULL   -- Do not update EditDate
      WHERE WorkStation = @c_workstation
      AND   StorerKey = @c_storerkey
      AND   Status = '5'
   END
      
   SELECT StorerKey,
      WorkStation,
		OrderKey, 
		ExternPOKey,
      IDS_Company,
      IDS_Address1,
      IDS_Address2,
      IDS_Address3,
      IDS_Address4,
      IDS_City, 
      IDS_Country,
		ConsigneeKey,
      C_Company,
      C_Address1,  
      C_Address2,
      C_Address3,
      C_Address4,
      C_City,
      C_Country,
		Sku,  
      SkuDescr,
		QtyCases,	
      QtyEaches,
      GroupID,
      PalletID,
      CaseID,
      ReprintFlag,
      Type,
      RefNo1,  -- SOS50521
      RefNo2,  -- SOS50521
      RefNo3,  -- SOS50521
		Lottable02,
		Lottable04
   FROM @TEMPPACK

   -- EXIT if encounter error
   EXIT_SP: 
   IF @n_continue = 3
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      ROLLBACK TRAN
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

END


GO