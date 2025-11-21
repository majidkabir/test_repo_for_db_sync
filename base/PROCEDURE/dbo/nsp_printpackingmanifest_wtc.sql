SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  nsp_PrintPackingManifest_WTC                       */  
/* Creation Date: 06-Feb-2006                                 */  
/* Copyright: IDS                                                       */  
/* Written by: MaryVong                                             */  
/*                                                                      */  
/* Purpose:  Create to Packing Manifest (Pallet/Tote)         */  
/*           SOS45053 WTCPH - Print Packing Manifest                    */  
/*           Notes: 1) This is used by a stand alone application named  */  
/*                     'WTC - Packing Manifest'                         */  
/*                  2) Provide Print Current and Reprint options        */  
/*                  3) Packing Manifest will be printed after user end- */  
/*                     scan one pallet or tote (thru RDT)               */  
/*                  4) User can reprint by entering sufficient params   */  
/*                                                                      */  
/* Input Parameters:  @c_storerkey,    - storerkey          */  
/*        @c_workstation,  - workstation to do scanning     */  
/*                    @c_consigneekey, - store which stock shipped to   */  
/*                    @c_refno,        - can be Pallet ID or Tote #     */  
/*                    @c_scandate      - scanning date                  */  
/*                                                                      */  
/* Called By:  dw = r_dw_packingmanifest_wtc                  */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/*                        */  
/************************************************************************/  
  
CREATE PROC [dbo].[nsp_PrintPackingManifest_WTC] (  
   @c_storerkey      NVARCHAR(15),   
   @c_workstation    NVARCHAR(15),  
   @c_consigneekey   NVARCHAR(15),  
   @c_refno          NVARCHAR(18),  
   @c_scandate       NVARCHAR(20) -- not confirm yet  
)     
AS  
BEGIN  
 SET NOCOUNT ON  
  
   DECLARE   
      @c_ReprintFlag       NVARCHAR(1), -- Y/N  
       
    @n_continue        int,  
    @n_err         int,  
    @c_errmsg        NVARCHAR(255),  
    @b_success        int,  
  @n_starttcnt         int,  
      @b_debug             int  
  
   SELECT @n_continue = 1  
   SELECT @n_starttcnt = @@TRANCOUNT  
  
   SELECT @b_debug = 0   
  
   SELECT @c_ReprintFlag = 'N'  
  
   CREATE TABLE #TEMPPACK (  
         StorerKey         NVARCHAR(15),  
   WorkStation     NVARCHAR(15),  
   OrderKey    NVARCHAR(10),   
   ExternPOKey       NVARCHAR(20),   
         IDS_Company       NVARCHAR(45),  
         IDS_Address1      NVARCHAR(45)   NULL,    
         IDS_Address2      NVARCHAR(45)   NULL,  
         IDS_Address3      NVARCHAR(45)   NULL,  
         IDS_Address4      NVARCHAR(45)   NULL,  
         IDS_City          NVARCHAR(45)   NULL,  
         IDS_Country       NVARCHAR(30)   NULL,  
   ConsigneeKey  NVARCHAR(15),  
         C_Company         NVARCHAR(45)   NULL,  
         C_Address1        NVARCHAR(45)   NULL,    
         C_Address2        NVARCHAR(45)   NULL,  
         C_Address3        NVARCHAR(45)   NULL,  
         C_Address4        NVARCHAR(45) NULL,  
         C_City            NVARCHAR(45)   NULL,  
         C_Country         NVARCHAR(30)   NULL,  
   Sku     NVARCHAR(20)   NULL,    
         SkuDescr          NVARCHAR(60)   NULL,  
   QtyCases    int,   
         QtyEaches         int,  
         ReprintFlag       NVARCHAR(1))   
  
   /***********************************************************************************  
    If NO parameters entered, retrieve all records for the particular workstation,   
    ie. records with status '5' (End Scanned) and update status to '9' after printed;  
    Otherwise, retrieve based on provided parameters.  
    Notes: StorerKey and WorkStation are captured from INI file  
   ************************************************************************************/  
  
   IF (dbo.fnc_RTRIM(dbo.fnc_LTRIM(@c_storerkey)) IS NULL OR dbo.fnc_RTRIM(dbo.fnc_LTRIM(@c_storerkey)) = '')   
   BEGIN  
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63101     
    SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Storerkey is blank. ' +   
                         ' (nsp_PrintStoreAddressedLabel_WTC)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '  
      GOTO EXIT_SP        
   END  
     
   IF (dbo.fnc_RTRIM(dbo.fnc_LTRIM(@c_workstation)) IS NULL OR dbo.fnc_RTRIM(dbo.fnc_LTRIM(@c_workstation)) = '')   
   BEGIN  
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63102     
    SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': WorkStation is blank. ' +   
                         ' (nsp_PrintStoreAddressedLabel_WTC)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '  
      GOTO EXIT_SP          
   END           
  
   -- No parameter entered (first time printing)  
   IF (dbo.fnc_RTRIM(dbo.fnc_LTRIM(@c_consigneekey)) IS NULL OR dbo.fnc_RTRIM(dbo.fnc_LTRIM(@c_consigneekey)) = '') AND  
      (dbo.fnc_RTRIM(dbo.fnc_LTRIM(@c_refno)) IS NULL OR dbo.fnc_RTRIM(dbo.fnc_LTRIM(@c_refno)) = '') AND  
      (dbo.fnc_RTRIM(dbo.fnc_LTRIM(@c_scandate)) IS NULL OR dbo.fnc_RTRIM(dbo.fnc_LTRIM(@c_scandate)) = '')  
   BEGIN  
      SELECT @c_ReprintFlag = 'N'  
        
      /*********************************************************************************  
       1) Pallet -> Case           : PD.CaseID =  AU.CaseID and PD.SKU = AU.SKU  
       2) Tote                     : PD.CaseID =  AU.CaseID and PD.SKU = AU.SKU  
       3) Pallet -> Store-Addressed: PD.CaseID <> AU.CaseID and PD.CaseID = 'STORADDR'  
      **********************************************************************************/  
  
      -- Pallet -> Case  
      INSERT INTO #TEMPPACK  
      SELECT AU.StorerKey,  
            AU.WorkStation,  
            OH.OrderKey,  
            OD.ExternPOKey,  
            OG.Company,  
            OG.Address1,  
            OG.Address2,  
            OG.Address3,  
            OG.Address4,  
            OG.City,  
            OG.Country,  
            OH.ConsigneeKey,  
            OH.C_Company,  
            OH.C_Address1,   
            OH.C_Address2,   
            OH.C_Address3,   
            OH.C_Address4,  
            OH.C_City,   
            OH.C_Country,  
            AU.SKU,   
            AU.Descr,  
            CASE WHEN PK.CaseCnt > 0 THEN SUM (AU.CountQty_B / PK.CaseCnt)  
               ELSE 0  
            END, -- Cases  
            SUM (AU.CountQty_B), -- Eaches  
            @c_ReprintFlag  
      FROM  RDT.RDTCsAudit AU (NOLOCK)  
      INNER JOIN dbo.PickDetail PD (NOLOCK)  
         ON ( PD.CaseID = AU.CaseID AND PD.StorerKey = AU.StorerKey AND PD.SKU = AU.SKU )  
      INNER JOIN dbo.OrderDetail OD (NOLOCK)   
         ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)  
      INNER JOIN dbo.Orders OH (NOLOCK)  
         ON (OH.OrderKey = OD.OrderKey)           
      INNER JOIN dbo.Storer ST (NOLOCK)   
         ON (AU.ConsigneeKey = ST.StorerKey)  
      INNER JOIN dbo.SKU SKU (NOLOCK)   
         ON (SKU.StorerKey = AU.StorerKey AND SKU.SKU = AU.SKU)  
      INNER JOIN dbo.PACK PK (NOLOCK)  
         ON (SKU.PackKey = PK.PackKey)  
      LEFT OUTER JOIN dbo.Storer OG (NOLOCK)   
         ON (OG.StorerKey = 'IDS')  
      WHERE AU.WorkStation = @c_workstation  
         AND AU.StorerKey = @c_storerkey  
         AND AU.Status = '5'  
         AND AU.CaseID LIKE 'C%'  
      GROUP BY AU.StorerKey,  
            AU.WorkStation,  
            OH.OrderKey,  
            OD.ExternPOKey,  
            OG.Company,  
            OG.Address1,  
            OG.Address2,  
            OG.Address3,  
            OG.Address4,  
            OG.City,  
            OG.Country,  
            OH.ConsigneeKey,  
            OH.C_Company,  
            OH.C_Address1,   
            OH.C_Address2,   
            OH.C_Address3,   
            OH.C_Address4,  
            OH.C_City,   
            OH.C_Country,  
            AU.SKU,   
            AU.Descr,  
            PK.CaseCnt  
      ORDER BY OH.ConsigneeKey, AU.SKU  
  
      IF @b_debug = 1  
      BEGIN  
         SELECT 'First time printing - Pallet -> Case'  
         SELECT * FROM #TEMPPACK  
      END  
  
-----------------------------------------------------------------------------------------  
      -- Tote  
      INSERT INTO #TEMPPACK  
      SELECT AU.StorerKey,  
            AU.WorkStation,  
            OH.OrderKey,  
            OD.ExternPOKey,  
            OG.Company,  
            OG.Address1,  
            OG.Address2,  
            OG.Address3,  
            OG.Address4,  
            OG.City,  
            OG.Country,  
            OH.ConsigneeKey,  
            OH.C_Company,  
            OH.C_Address1,   
            OH.C_Address2,   
            OH.C_Address3,   
            OH.C_Address4,  
            OH.C_City,   
            OH.C_Country,  
            AU.SKU,   
            AU.Descr,  
            0, -- Cases  
            SUM (AU.CountQty_B), -- Eaches  
            @c_ReprintFlag  
      FROM  RDT.RDTCsAudit AU (NOLOCK)  
      INNER JOIN dbo.PickDetail PD (NOLOCK)  
         ON ( PD.CaseID = AU.CaseID AND PD.StorerKey = AU.StorerKey AND PD.SKU = AU.SKU )  
      INNER JOIN dbo.OrderDetail OD (NOLOCK)   
         ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)  
      INNER JOIN dbo.Orders OH (NOLOCK)  
         ON (OH.OrderKey = OD.OrderKey)           
      INNER JOIN dbo.Storer ST (NOLOCK)   
         ON (AU.ConsigneeKey = ST.StorerKey)  
      INNER JOIN dbo.SKU SKU (NOLOCK)   
         ON (SKU.StorerKey = AU.StorerKey AND SKU.SKU = AU.SKU)  
      INNER JOIN dbo.PACK PK (NOLOCK)  
         ON (SKU.PackKey = PK.PackKey)  
      LEFT OUTER JOIN dbo.Storer OG (NOLOCK)   
         ON (OG.StorerKey = 'IDS')  
      WHERE AU.WorkStation = @c_workstation  
         AND AU.StorerKey = @c_storerkey  
         AND AU.Status = '5'  
         AND AU.CaseID LIKE 'T%'  
      GROUP BY AU.StorerKey,  
            AU.WorkStation,  
            OH.OrderKey,  
            OD.ExternPOKey,  
            OG.Company,  
            OG.Address1,  
            OG.Address2,  
            OG.Address3,  
            OG.Address4,  
            OG.City,  
            OG.Country,  
            OH.ConsigneeKey,  
            OH.C_Company,  
            OH.C_Address1,   
            OH.C_Address2,   
            OH.C_Address3,   
            OH.C_Address4,  
            OH.C_City,   
            OH.C_Country,  
            AU.SKU,   
            AU.Descr,  
            PK.CaseCnt  
      ORDER BY OH.ConsigneeKey, AU.SKU  
  
      IF @b_debug = 1  
      BEGIN  
         SELECT 'First time printing - Tote'  
         SELECT * FROM #TEMPPACK  
      END  
-----------------------------------------------------------------------------------------  
  
      -- Store-Addressed  
      INSERT INTO #TEMPPACK  
      SELECT AU.StorerKey,  
            AU.WorkStation,  
            OH.OrderKey,         
            OD.ExternPOKey,  
            OG.Company,  
            OG.Address1,  
            OG.Address2,  
            OG.Address3,  
            OG.Address4,  
            OG.City,  
            OG.Country,  
            OH.ConsigneeKey,  
            OH.C_Company,  
            OH.C_Address1,   
            OH.C_Address2,   
            OH.C_Address3,   
            OH.C_Address4,  
            OH.C_City,   
            OH.C_Country,  
            AU.SKU,   
            AU.CaseID, -- update AU.CaseID into skudescr column  
            1, -- Cases  
            0, -- Eaches  
            @c_ReprintFlag  
      FROM  RDT.RDTCsAudit AU (NOLOCK)  
      INNER JOIN dbo.PickDetail PD (NOLOCK)  
         ON (PD.StorerKey = AU.StorerKey )  
      INNER JOIN dbo.OrderDetail OD (NOLOCK)   
         ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)  
      INNER JOIN dbo.Orders OH (NOLOCK)  
         ON (OH.OrderKey = OD.OrderKey)           
      INNER JOIN dbo.Storer ST (NOLOCK)   
         ON (AU.ConsigneeKey = ST.StorerKey)  
      INNER JOIN RECEIPTDETAIL RD (NOLOCK)  
         ON (RD.ReceiptKey = SUBSTRING(AU.CaseID, 2, 10) AND RD.ExternReceiptKey = OD.ExternPOKey)  
      LEFT OUTER JOIN dbo.Storer OG (NOLOCK)   
         ON (OG.StorerKey = 'IDS')  
      WHERE AU.WorkStation = @c_workstation  
         AND AU.StorerKey = @c_storerkey  
         AND AU.Status = '5'  
         AND PD.CaseID = '(STORADDR)'   
         AND AU.CaseID LIKE 'S%'  
      GROUP BY AU.StorerKey,  
            AU.WorkStation,  
            OH.OrderKey,         
            OD.ExternPOKey,  
            OG.Company,  
            OG.Address1,  
            OG.Address2,  
            OG.Address3,  
            OG.Address4,  
            OG.City,  
            OG.Country,  
            OH.ConsigneeKey,  
            OH.C_Company,  
            OH.C_Address1,   
            OH.C_Address2,   
            OH.C_Address3,   
            OH.C_Address4,  
            OH.C_City,   
            OH.C_Country,  
            AU.SKU,   
            AU.Descr,  
            AU.CaseID  
      ORDER BY OH.ConsigneeKey, AU.CaseID  
  
      IF @b_debug = 1  
      BEGIN  
         SELECT 'First time printing - Pallet -> Store-Addressed'  
         SELECT * FROM #TEMPPACK  
      END  
        
-----------------------------------------------------------------------------------------  
           
   END  
   ELSE           
   BEGIN  
      SELECT @c_ReprintFlag = 'Y'  
             
      SELECT OD.ExternPOKey,   
            AU.SKU,   
            AU.Descr,   
            Cases ='',   
            AU.CountQty_B,   
            OH.ConsigneeKey,   
            OH.C_Address1,   
            OH.C_Address2,   
            OH.C_Address3,   
            OH.C_Address4,  
            OH.C_City,   
            OH.C_Country  
      FROM  dbo.PickDetail PD (NOLOCK)  
      INNER JOIN RDT.RDTCsAudit AU (NOLOCK)  
         ON ( (PD.CaseID = AU.CaseID AND PD.StorerKey = AU.StorerKey AND PD.SKU = AU.SKU) OR  
              (PD.CaseID <> AU.CaseID) AND PD.CaseID = '(STORADDR)' )  
      INNER JOIN dbo.OrderDetail OD (NOLOCK)   
         ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)  
      INNER JOIN dbo.Orders OH (NOLOCK)  
         ON (OH.OrderKey = OD.OrderKey)           
      INNER JOIN dbo.Storer ST (NOLOCK)   
         ON (AU.ConsigneeKey = ST.StorerKey)  
      WHERE AU.WorkStation = @c_workstation  
         AND AU.StorerKey = @c_storerkey  
         AND ( (AU.PalletID = @c_refno) OR   
               (AU.CaseID = @c_refno) )  
         AND AU.EditDate = CONVERT (datetime, @c_scandate)  
         AND AU.Status = '9'  
   END  
  
   -- IF first time printing, update rdtCsAudit.Status = '9' after printed  
   IF @c_ReprintFlag = 'N'  
   BEGIN  
      UPDATE RDT.RDTCsAudit  
      SET   Status = '9'  
      WHERE WorkStation = @c_workstation  
      AND   StorerKey = @c_storerkey  
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
      ReprintFlag     
   FROM #TEMPPACK  
  
   DROP TABLE #TEMPPACK  
  
  
   -- EXIT if encounter error  
   EXIT_SP:   
   IF @n_continue = 3  
   BEGIN  
      WHILE @@TRANCOUNT > @n_starttcnt  
      ROLLBACK TRAN  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_PrintPackingManifest_WTC'  
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