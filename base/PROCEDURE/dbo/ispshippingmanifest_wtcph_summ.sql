SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: ispShippingManifest_WTCPH_Summ                      */
/* Creation Date: 2-Jul-2007                                            */
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                                 */
/*                                                                      */
/* Purpose: IDSPH Watsons Shipping Manifest by Batch (SOS76510)         */
/*          - Summary Report                                            */
/*                                                                      */
/* Called By: r_dw_shippingmanifest_wtcph_summ                          */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 04-Sep-2008  Shong      Performance Tuning                           */
/************************************************************************/

CREATE PROC [dbo].[ispShippingManifest_WTCPH_Summ] ( 
   @c_parmDummyLoad  NVARCHAR(10),  
   @c_parmBatch      NVARCHAR(15) )  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE   
      @b_success   int,  
      @n_err       int,  
      @c_errmsg    NVARCHAR(250)  
  
   DECLARE  
      -- IDS company address  
      @cIDSCompany      NVARCHAR(45),  
      @cIDSAddress1     NVARCHAR(45),  
      @cIDSAddress2     NVARCHAR(45),  
      @cIDSAddress3     NVARCHAR(45),  
      -- LoadPlan  
      @cLPUserDefine10  NVARCHAR(10),  
      @dtLPAddDate      datetime,  
      -- Consignee  
      @cConsigneeKey    NVARCHAR(15),  
      @cC_Company       NVARCHAR(45),  
      @cC_Address1      NVARCHAR(45),  
      @cC_Address2      NVARCHAR(45),  
      @cC_Address3      NVARCHAR(45),  
      @cDelArea         NVARCHAR(18),   -- STORER.Zip where storerkey = consigneekey  
      @cStorerKey       NVARCHAR(15),  
      @cLoadKey         NVARCHAR(10),  
      @cChildLoad       NVARCHAR(10),  
      @cDrNum           NVARCHAR(8)  
     
   SELECT  
      @b_success    = 0,  
      @n_err        = 0,  
      @c_errmsg     = ''  
  
   /*************************/  
   /* Declare temp tables   */  
   /*************************/  
   IF OBJECT_ID('tempdb..#tLoad') IS NOT NULL
      DROP TABLE #tLoad

   CREATE TABLE #tLoad 
   (  
      LoadKey NVARCHAR( 10) NOT NULL,  
      DRNum   NVARCHAR( 10) DEFAULT ('')  
      PRIMARY KEY CLUSTERED (Loadkey, DRNum)  
   )  

   IF OBJECT_ID('tempdb..#tResult_CT') IS NOT NULL
      DROP TABLE #tResult_CT
     
   --DECLARE #tResult_CT TABLE  
   CREATE TABLE #tResult_CT
   (  
      ConsigneeKey NVARCHAR( 15) NOT NULL,   
      SKU          NVARCHAR( 20) NOT NULL,  
      DRNum        NVARCHAR( 10) NULL DEFAULT (''),   
      OrderQTY     INT DEFAULT (0),   
      PDQTY        INT DEFAULT (0),   
      RDTQTY       INT DEFAULT (0)  
      PRIMARY KEY CLUSTERED (ConsigneeKey, SKU)  
   )     

   IF OBJECT_ID('tempdb..#tResult_SA') IS NOT NULL
      DROP TABLE #tResult_SA

   CREATE TABLE #tResult_SA      
   (  
      ConsigneeKey NVARCHAR( 15) NOT NULL,   
      SKU          NVARCHAR( 20) NOT NULL,  
      DRNum        NVARCHAR( 10) NULL DEFAULT (''),   
      OrderQTY     INT NULL DEFAULT (0),   
      PDQTY        INT NULL DEFAULT (0),   
      RDTQTY       INT NULL DEFAULT (0)  
      PRIMARY KEY CLUSTERED (ConsigneeKey, SKU)  
   )  

   IF OBJECT_ID('tempdb..#tConsignee_SKU') IS NOT NULL
      DROP TABLE #tConsignee_SKU

   CREATE TABLE #tConsignee_SKU 
   (  
      ConsigneeKey NVARCHAR( 15) NOT NULL,   
      SKU          NVARCHAR( 20) NOT NULL,  
      Qty          INT DEFAULT (0)  
      PRIMARY KEY CLUSTERED (ConsigneeKey, SKU)  
   )  
  
   -- Get IDS company addresses  
   SELECT   
      @cIDSCompany   = Company,  
      @cIDSAddress1  = Address1,  
      @cIDSAddress2  = Address2,  
      @cIDSAddress3  = Address3  
   FROM STORER (NOLOCK)  
   WHERE StorerKey = 'IDS'  
  
   -- Get StorerKey and LoadPlan adddate (only get 1 line)  
   SET ROWCOUNT 1  
  
   SELECT  
      @cStorerKey = O.StorerKey,  
      @dtLPAddDate = L.AddDate  
   FROM LOADPLAN L (NOLOCK)  
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON (L.LoadKey = LPD.LoadKey)  
   JOIN ORDERS O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)  
   WHERE L.UserDefine09 = @c_parmDummyLoad  
     
   SET ROWCOUNT 0     
     
   /*********************************************/  
   /* Generate DR# if not exists                */  
   /*********************************************/  
   IF EXISTS ( SELECT 1 FROM LOADPLAN L (NOLOCK)  
               JOIN LOADPLANDETAIL LPD (NOLOCK) ON (L.LoadKey = LPD.LoadKey)  
               JOIN ORDERS O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)  
               WHERE L.UserDefine09 = @c_parmDummyLoad  
               AND (L.UserDefine10 = '' OR L.UserDefine10 IS NULL) )  
   BEGIN  
      SELECT @cChildLoad = ''  
     
      DECLARE @curLoad CURSOR  
      SET @curLoad = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
      SELECT L.LoadKey  
      FROM LOADPLAN L (NOLOCK)  
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON (L.LoadKey = LPD.LoadKey)  
      JOIN ORDERS O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)  
      WHERE L.UserDefine09 = @c_parmDummyLoad  
      AND (L.UserDefine10 = '' OR L.UserDefine10 IS NULL)  
      ORDER BY L.LoadKey   
     
      OPEN @curLoad  
        
      FETCH NEXT FROM @curLoad INTO @cChildLoad  
        
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         -- Generate DR #  
         SELECT @b_success = 0  
         EXECUTE nspg_GetKey  
         'DR'  
         , 7  
         , @cDrNum OUTPUT  
         , @b_success OUTPUT  
         , @n_err OUTPUT  
         , @c_errmsg OUTPUT        
        
         IF @b_success = 1  
         BEGIN  
            -- Update LOADPLAN.UserDefine10  
            SELECT @cDrNum = 'B' + @cDrNum  
              
            BEGIN TRAN  
              
            UPDATE LOADPLAN WITH (ROWLOCK)   
            SET TrafficCop = NULL,  
               UserDefine10 = @cDrNum   
            WHERE LoadKey = @cChildLoad  
           
            SELECT @n_err = @@error  
            IF @n_err = 0  
               COMMIT TRAN  
            ELSE  
            BEGIN  
               ROLLBACK TRAN  
               SELECT @c_errmsg = 'Update On Loadplan For Shipping Manifest# Failed.'  
               EXECUTE nsp_LogError   
               @@error,   
               @c_errmsg,  
               'ispShippingManifest_WTCTH_Det_Summ'  
               RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
               RETURN  
            END   
         END  
        
         FETCH NEXT FROM @curLoad INTO @cChildLoad  
      END  
     
      SELECT @b_success = 1  
     
      EXEC dbo.ispGenTransmitlog2 'WTS-DR', @c_parmDummyLoad, '', '', ''  
      , @b_success OUTPUT  
      , @n_err OUTPUT  
      , @c_errmsg OUTPUT      
        
      IF @b_success <> 1  
      BEGIN  
         SELECT @n_err = 72800  
         SELECT @c_errmsg = 'Generate WTS-DR Transmitlog2 Interface Failed.'  
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
         RETURN           
      END  
   END           
        
   /************************************************************************/  
   /* Types of WTCTH orders:                                               */  
   /* 1. CrossDock - Orders.Type = 'C' and PO.POType = 'C' (link the po)   */  
   /* 2. Storage   - Orders.Type = 'S'                                     */  
   /* 3. StoreAddr - Orders.Type = 'C' and PO.POType = 'SA' (link the po)  */  
   /************************************************************************/  
   /************************************************************************/
   /* Types of WTCTH orders:                                               */
   /* 1. CrossDock - Orders.Type = 'XAC' and PO.POType = no fix value (link the po)   */
   /* 2. Storage   - Orders.Type <> 'XAC'                                     */
   /************************************************************************/
     
   -- Get all loadkey  
   INSERT INTO #tLoad (LoadKey, DRNum)  
   SELECT LoadKey, UserDefine10   
   FROM LoadPlan (NOLOCK)  
   WHERE UserDefine09 = @c_parmDummyLoad  
     
   /**************************************************/  
   /* At #tResult_CT (CrossDock & Storage stocks):   */  
   /* 1) Insert OrderQTY for all                     */  
   /* 2) Update PDQty                                */  
   /* 3) Update RDTQty                               */  
   /* 4) Insert RDT data if not exists in temp table */  
   /**************************************************/  
  
   -- 1. Insert OrderQTY  
   INSERT INTO #tResult_CT (ConsigneeKey, SKU, DRNum, OrderQTY)  
   SELECT O.ConsigneeKey, OD.SKU, L.DRNum, SUM( OD.OriginalQTY)  
   FROM #tLoad L   
      INNER JOIN LoadPlanDetail LPD (NOLOCK) ON (LPD.LoadKey = L.LoadKey)  
      INNER JOIN Orders O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)  
      INNER JOIN OrderDetail OD (NOLOCK) ON (O.OrderKey = OD.OrderKey)  
      LEFT OUTER JOIN PO PO (NOLOCK) ON (O.StorerKey = PO.StorerKey AND O.POKey = PO.ExternPOKey)  
   WHERE   
      --(O.Type = 'C' AND PO.POType = 'C') OR
      --(O.Type = 'S')
      (O.Type = 'XAC' OR O.Type <> 'XAC')   
   GROUP BY O.ConsigneeKey, OD.SKU, L.DRNum  
   HAVING SUM( OD.QtyAllocated + QtyPicked + ShippedQty) > 0  
     
   -- 2. Update PDQTY  
   UPDATE t SET  
      PDQTY = A.QTY  
   FROM #tResult_CT t
   INNER JOIN  
   (  
      SELECT O.ConsigneeKey, OD.SKU, SUM( PD.QTY) QTY  
      FROM #tLoad L  
         INNER JOIN LoadPlanDetail LPD (NOLOCK) ON (LPD.LoadKey = L.LoadKey)  
         INNER JOIN Orders O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)  
         INNER JOIN OrderDetail OD (NOLOCK) ON (O.OrderKey = OD.OrderKey)  
         INNER JOIN PickDetail PD (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)  
      WHERE PD.CaseID <> '(STORADDR)'  
      GROUP BY O.ConsigneeKey, OD.SKU  
   ) A ON (A.ConsigneeKey = t.ConsigneeKey AND A.SKU = t.SKU)  
     
   -- 3. Update RDTQTY  
   DELETE #tConsignee_SKU

   INSERT INTO #tConsignee_SKU (ConsigneeKey, SKU, QTY)
   SELECT AU.ConsigneeKey, AU.SKU, SUM( AU.CountQTY_B) CountQTY_B  
   FROM RDT.RDTCSAudit_BATCH BA (NOLOCK)   
      INNER JOIN RDT.RDTCSAudit AU (NOLOCK) ON (BA.BatchID = AU.BatchID)  
   WHERE BA.Batch = @c_parmBatch  
   AND   BA.CloseDate <> ''  
   AND   AU.Status >= '5' -- 5=End scanned, 9=Printed  
      --AND   AU.Type <> 'S'   -- S=store addressed
	  AND   AU.Type <> 'XAC'   -- S=store addressed  
   GROUP BY AU.ConsigneeKey, AU.SKU 

   UPDATE t 
	SET  RDTQTY = A.Qty  
   FROM #tResult_CT t 
   INNER JOIN #tConsignee_SKU AS A ON (A.ConsigneeKey = t.ConsigneeKey AND A.SKU = t.SKU)  
     
   -- 4. Insert RDTQTY - if not found in temp table #tResult_CT  
   INSERT INTO #tResult_CT (ConsigneeKey, SKU, RDTQTY)  
   SELECT AU.ConsigneeKey, AU.SKU, SUM( AU.CountQTY_B)  
   FROM RDT.RDTCSAudit_BATCH BA (NOLOCK)   
      INNER JOIN RDT.RDTCSAudit AU (NOLOCK) ON (BA.BatchID = AU.BatchID)  
      LEFT OUTER JOIN #tResult_CT t ON (AU.ConsigneeKey = t.ConsigneeKey AND AU.SKU = t.SKU)  
   WHERE BA.Batch = @c_parmBatch  
   AND   BA.CloseDate <> ''  
   AND   AU.Status >= '5' -- 5=End scanned, 9=Printed  
   --AND   AU.Type <> 'S'   -- S=store addressed
   AND   AU.Type <> 'XAC'   -- S=store addressed 
   AND   t.ConsigneeKey IS NULL  
   GROUP BY AU.ConsigneeKey, AU.SKU  
     
   /**************************************************/  
   /* At #tResult_SA (Store Addresse stocks):        */  
   /* 5) Insert OrderQTY for all                     */  
   /* 6) Update PDQty                                */  
   /**************************************************/  
   -- 5. Insert OrderQTY  
   INSERT INTO #tResult_SA (ConsigneeKey, SKU, DRNum, OrderQTY)  
   SELECT O.ConsigneeKey, OD.SKU, L.DRNum, SUM( OD.OriginalQTY)  
   FROM #tLoad L  
      INNER JOIN LoadPlanDetail LPD (NOLOCK) ON (LPD.LoadKey = L.LoadKey)  
      INNER JOIN Orders O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)  
      INNER JOIN OrderDetail OD (NOLOCK) ON (O.OrderKey = OD.OrderKey)  
      INNER JOIN PO PO (NOLOCK) ON (O.StorerKey = PO.StorerKey AND O.POKey = PO.ExternPOKey)  
   WHERE --O.Type = 'C' AND PO.POType = 'SA'
         O.Type = 'XAC'   
   GROUP BY O.ConsigneeKey, OD.SKU, L.DRNum  
   HAVING SUM( OD.QtyAllocated + QtyPicked + ShippedQty) > 0  
     
   -- 6. Update PDQTY  
   UPDATE #tResult_SA SET   
      PDQTY = A.PDQTY  
   FROM  
   (  
      SELECT O.ConsigneeKey, OD.SKU, SUM( PD.QTY) PDQTY  
      FROM #tLoad L  
         INNER JOIN LoadPlanDetail LPD (NOLOCK) ON (LPD.LoadKey = L.LoadKey)  
         INNER JOIN Orders O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)  
         INNER JOIN OrderDetail OD (NOLOCK) ON (O.OrderKey = OD.OrderKey)  
         INNER JOIN PickDetail PD (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)  
      WHERE PD.CaseID = '(STORADDR)'  
      GROUP BY O.ConsigneeKey, OD.SKU  
   ) A  
   INNER JOIN #tResult_SA t ON (A.ConsigneeKey = t.ConsigneeKey AND A.SKU = t.SKU)  
     
--   select count(1) from #tResult_CT  
--   select count(1) from #tResult_SA  
     
   -- Return results  
   SELECT 'CT',              t.ConsigneeKey,     t.SKU,              t.OrderQTY,   
      t.PDQTY,               t.RDTQTY,           t.DRNum,            S.Descr,              
      S.Price,               ST.Company,         ST.Address1,        ST.Address2,          
      ST.Address3,           ST.Zip,             @cIDSCompany,       @cIDSAddress1,  
      @cIDSAddress2,         @cIDSAddress3,      @dtLPAddDate        
   FROM #tResult_CT t  
   INNER JOIN SKU S (NOLOCK) ON (S.StorerKey = @cStorerKey AND t.SKU = S.SKU)  
   INNER JOIN STORER ST (NOLOCK) ON (ST.StorerKey = t.ConsigneeKey)  
   UNION ALL  
   SELECT 'SA',              t.ConsigneeKey,     t.SKU,              t.OrderQTY,   
      t.PDQTY,               t.RDTQTY,           t.DRNum,            S.Descr,  
      S.Price,               ST.Company,         ST.Address1,        ST.Address2,  
      ST.Address3,           ST.Zip,             @cIDSCompany,       @cIDSAddress1,  
      @cIDSAddress2,         @cIDSAddress3,      @dtLPAddDate        
   FROM #tResult_SA t  
   INNER JOIN SKU S (NOLOCK) ON (S.StorerKey = @cStorerKey AND t.SKU = S.SKU)  
   INNER JOIN STORER ST (NOLOCK) ON (ST.StorerKey = t.ConsigneeKey)  
    
END 

GO