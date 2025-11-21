SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: ispShippingManifest_WTCPH_Det_Main                  */
/* Creation Date: 28-Jun-2007                                           */
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                                 */
/*                                                                      */
/* Purpose: IDSPH Watsons Shipping Manifest by Batch (SOS76510)         */
/*          - Detail Report                                             */
/*          - Get TotalQty, Consignee and LoadPlan data                 */
/*                                                                      */
/* Called By: r_dw_shippingmanifest_wtcph_det, nested with sub reports: */
/*            1) r_dw_shippingmanifest_wtcph_det_case                   */
/*            2) r_dw_shippingmanifest_wtcph_det_tote                   */
/*            3) r_dw_shippingmanifest_wtcph_det_storeaddr              */
/*                                                                      */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 01-Sep-2008  Shong      Performance Tuning                           */
/* 2008-Sep-23  Shong      1. To Revolved Blocking Issues               */
/* 2009-Jan-15  Leong      SOS#126941 - Prevent Skip DR Series Number   */
/************************************************************************/

CREATE PROC [dbo].[ispShippingManifest_WTCPH_Det_Main] (
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
      @c_errmsg    NVARCHAR(250), 
      @nTransCount int 

   SET @nTransCount = @@TRANCOUNT 

   BEGIN TRAN
      
   DECLARE
      -- IDS company address
      @cIDSCompany      NVARCHAR(45),
      @cIDSAddress1     NVARCHAR(45),
      @cIDSAddress2     NVARCHAR(45),
      @cIDSAddress3     NVARCHAR(45),
      -- LoadPlan
      @cDrNum_UsrDf10   NVARCHAR(10),
      @dtLPAddDate      datetime,
      -- Consignee
      @cConsigneeKey    NVARCHAR(15),
      @cC_Company       NVARCHAR(45),
      @cC_Address1      NVARCHAR(45),
      @cC_Address2      NVARCHAR(45),
      @cC_Address3      NVARCHAR(45),
      -- TotalQty      
      @nSTotal          int,
      @nBTotal          int,
      @nRTotal          int,
      @nCTotal          int,
      @nTTotal          int,
      @nKTotal          int,
      @nVTotal          int,
      @cStorerKey       NVARCHAR(15),
      @cChildLoad       NVARCHAR(10),
      @cDrNum           NVARCHAR(8),
      @cDelArea         NVARCHAR(18)

   SELECT
      @b_success    = 0,
      @n_err        = 0,
      @c_errmsg     = ''

   SELECT
      @nSTotal       = 0,
      @nBTotal       = 0,
      @nRTotal       = 0,
      @nCTotal       = 0,
      @nTTotal       = 0,
      @nKTotal       = 0,
      @nVTotal       = 0

   IF OBJECT_ID('tempdb..#tTempData') IS NOT NULL
      DROP TABLE #tTempData
   
   CREATE TABLE #tTempData (
      ConsigneeKey    NVARCHAR(15),
      Type            NVARCHAR(1),
      CaseID          NVARCHAR(18) 
   )

   IF OBJECT_ID('tempdb..#tTempResult') IS NOT NULL
      DROP TABLE #tTempResult

   CREATE TABLE #tTempResult (
      RowID           int identity (1,1),
      ConsigneeKey    NVARCHAR(15),
      -- Case
      CTotal          int default 0,
      -- Tote
      TTotal          int default 0,
      KTotal          int default 0,
      VTotal          int default 0,
      -- Store-Addressed
      STotal          int default 0,
      BTotal          int default 0,
      RTotal          int default 0,
      IDSCompany      NVARCHAR(45) NULL default '',
      IDSAddress1     NVARCHAR(45) NULL default '',
      IDSAddress2     NVARCHAR(45) NULL default '',
      IDSAddress3     NVARCHAR(45) NULL default '',
      C_Company       NVARCHAR(45) NULL default '',
      C_Address1      NVARCHAR(45) NULL default '',
      C_Address2      NVARCHAR(45) NULL default '',
      C_Address3      NVARCHAR(45) NULL default '',
      DelArea         NVARCHAR(18) NULL default '',   -- STORER.Zip where storerkey = consigneekey
      DrNum_UsrDf10   NVARCHAR(10) NULL default '',
      LPAddDate       datetime NULL,
      DummyLoad       NVARCHAR(10) NULL default '',
      Batch           NVARCHAR(15) NULL default ''
   )

   -- Get IDS company addresses
   SELECT 
      @cIDSCompany   = Company,
      @cIDSAddress1  = Address1,
      @cIDSAddress2  = Address2,
      @cIDSAddress3  = Address3
   FROM STORER WITH (NOLOCK)
   WHERE StorerKey = 'IDS'

   SET ROWCOUNT 1
   
   -- Get StorerKey and LoadPlan adddate (only get 1 line)
   SELECT
      @cStorerKey = OH.StorerKey,
      @dtLPAddDate = LP.AddDate
   FROM LOADPLAN LP (NOLOCK)
   JOIN LOADPLANDETAIL LD (NOLOCK) ON (LP.LoadKey = LD.LoadKey)
   JOIN ORDERS OH (NOLOCK) ON (LD.OrderKey = OH.OrderKey)
   WHERE LP.UserDefine09 = @c_parmDummyLoad
   
   SET ROWCOUNT 0

   /*********************************************/
   /* Generate DR# if not exists                */
   /*********************************************/
-- IF EXISTS ( SELECT DISTINCT lp.userdefine10 FROM LOADPLAN LP (NOLOCK) -- SOS#126941
   IF EXISTS ( SELECT DISTINCT 1 FROM LOADPLAN LP (NOLOCK) -- SOS#126941
               JOIN LOADPLANDETAIL LD (NOLOCK) ON (LP.LoadKey = LD.LoadKey)
               JOIN ORDERS OH (NOLOCK) ON (LD.OrderKey = OH.OrderKey)
               WHERE LP.UserDefine09 = @c_parmDummyLoad
               AND OH.StorerKey = @cStorerKey
               AND (LP.UserDefine10 = '' OR LP.UserDefine10 IS NULL) )
   BEGIN
      SELECT @cChildLoad = ''
   
      DECLARE @curLoad CURSOR
      SET @curLoad = CURSOR READ_ONLY FAST_FORWARD FOR
 
      -- SELECT LP.LoadKey       -- SOS#126941
      SELECT DISTINCT LP.LoadKey -- SOS#126941
      FROM LOADPLAN LP (NOLOCK)
      JOIN LOADPLANDETAIL LD (NOLOCK) ON (LP.LoadKey = LD.LoadKey)
      JOIN ORDERS OH (NOLOCK) ON (LD.OrderKey = OH.OrderKey)
      WHERE LP.UserDefine09 = @c_parmDummyLoad
      AND  OH.StorerKey = @cStorerKey
      AND (LP.UserDefine10 = '' OR LP.UserDefine10 IS NULL)
      ORDER BY LP.LoadKey 
   
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
            WHILE @@TRANCOUNT > 0 
               COMMIT TRAN  
                           
            -- Update LOADPLAN.UserDefine10
            SELECT @cDrNum = 'B' + @cDrNum
            
            BEGIN TRAN
            
            UPDATE LOADPLAN WITH (ROWLOCK) 
            SET TrafficCop = NULL,
               UserDefine10 = @cDrNum
            WHERE LoadKey = @cChildLoad
         
            SELECT @n_err = @@error
            IF @n_err = 0
            BEGIN
               WHILE @@TRANCOUNT > 0 
                  COMMIT TRAN
            END 
            ELSE
            BEGIN
               ROLLBACK TRAN
               SELECT @c_errmsg = 'Update On Loadplan For Shipping Manifest# Failed.'
               EXECUTE nsp_LogError 
               @@error, 
               @c_errmsg,
               'ispShippingManifest_WTCPH_Det_Main'
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

      WHILE @@TRANCOUNT > 0 
         COMMIT TRAN        
   END

   /*********************************************/
   /* Get all matching data into tempData table */
   /*********************************************/
   INSERT INTO #tTempData
      (ConsigneeKey, Type, CaseID)
   SELECT AU.ConsigneeKey, AU.Type, AU.CaseID
   FROM RDT.RDTCSAudit AU WITH (NOLOCK)
   INNER JOIN RDT.RDTCSAudit_BATCH BA WITH (NOLOCK) ON (BA.BatchID = AU.BatchID)
   WHERE BA.Batch = @c_parmBatch
   AND   AU.StorerKey = @cStorerKey
--AND AU.ConsigneeKey IN ('wts-97','wts-394','wts-138','wts-1')
--AND AU.ConsigneeKey in ('wts-120','wts-121','wts-122','wts-123','wts-124')
   AND   AU.Status >= '5'   
   ORDER BY AU.ConsigneeKey, AU.Type, AU.CaseID

   -- Get distinct consigneekey
   DECLARE @curConsignee CURSOR
   SET @curConsignee = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT ConsigneeKey 
      FROM #tTempData
      ORDER BY ConsigneeKey

   OPEN @curConsignee
   FETCH NEXT FROM @curConsignee INTO @cConsigneeKey
     
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- Get consignee data
      SELECT       
         @cC_Company  = Company,
         @cC_Address1 = Address1,
         @cC_Address2 = Address2,
         @cC_Address3 = Address3,
         @cDelArea    = Zip
      FROM STORER (NOLOCK)
      WHERE StorerKey = @cConsigneeKey
      
      -- Get DR# for individual consignee
      SELECT DISTINCT @cDrNum_UsrDf10 = LP.UserDefine10
      FROM LOADPLAN LP (NOLOCK)
      INNER JOIN ORDERS OH (NOLOCK) ON (OH.LoadKey = LP.LoadKey)
      WHERE LP.UserDefine09 = @c_parmDummyLoad
      AND   OH.ConsigneeKey = @cConsigneeKey

      /*************************/
      /* Full Case             */
      /* Type = 'C'            */
      /* CaseID prefix = 'C'   */
      /*************************/
      -- 1 row in RDTCSAudit = 1 case
      SELECT @nCTotal = COUNT(CaseID)
      FROM #tTempData
      WHERE ConsigneeKey = @cConsigneeKey
      AND   Type = 'C'

      /**********************************/
      /* Tote                           */
      /* Type = 'T'                     */
      /* CaseID prefix = 'T','K','V'    */
      /**********************************/
      -- multiple rows in RDTCSAudit = 1 case
      SELECT @nKTotal = COUNT(DISTINCT CaseID)
      FROM #tTempData
      WHERE ConsigneeKey = @cConsigneeKey
      AND   Type = 'T'
      AND   SUBSTRING(CaseID,1,1) = 'K'

      SELECT @nTTotal = COUNT(DISTINCT CaseID)
      FROM #tTempData
      WHERE ConsigneeKey = @cConsigneeKey
      AND   Type = 'T'
      AND   SUBSTRING(CaseID,1,1) = 'T'

      SELECT @nVTotal = COUNT(DISTINCT CaseID)
      FROM #tTempData
      WHERE ConsigneeKey = @cConsigneeKey
      AND   Type = 'T'
      AND   SUBSTRING(CaseID,1,1) = 'V'

      /**********************************/
      /* Store-Addressed                */
      /* Type = 'S'                     */
      /* CaseID prefix = 'S','B','R'    */
      /**********************************/
      -- 1 row in RDTCSAudit = 1 case
      SELECT @nSTotal = COUNT(CaseID)
      FROM #tTempData
      WHERE ConsigneeKey = @cConsigneeKey
      AND   Type = 'S'
      AND   SUBSTRING(CaseID,1,1) = 'S'
      
      SELECT @nBTotal = COUNT(CaseID)
      FROM #tTempData
      WHERE ConsigneeKey = @cConsigneeKey
      AND   Type = 'S'
      AND   SUBSTRING(CaseID,1,1) = 'B'

      SELECT @nRTotal = COUNT(CaseID)
      FROM #tTempData
      WHERE ConsigneeKey = @cConsigneeKey
      AND   Type = 'S'
      AND   SUBSTRING(CaseID,1,1) = 'R'

      -- Insert into result table
      INSERT INTO #tTempResult
         (ConsigneeKey,   CTotal,         TTotal,         KTotal,      VTotal,
         STotal,          BTotal,         RTotal,         IDSCompany,  IDSAddress1,
         IDSAddress2,     IDSAddress3,    C_Company,      C_Address1,  C_Address2,
         C_Address3,      DelArea,        DrNum_UsrDf10,  LPAddDate,   DummyLoad, Batch )
      VALUES
         (@cConsigneeKey, @nCTotal,       @nTTotal,        @nKTotal,      @nVTotal,
         @nSTotal,        @nBTotal,       @nRTotal,        @cIDSCompany,  @cIDSAddress1,
         @cIDSAddress2,   @cIDSAddress3,  @cC_Company,     @cC_Address1,  @cC_Address2,
         @cC_Address3,    @cDelArea,      @cDrNum_UsrDf10, @dtLPAddDate,  @c_parmDummyLoad, 
         @c_parmBatch )
   
      FETCH NEXT FROM @curConsignee INTO @cConsigneeKey
   END

   -- Return result
   SELECT
      ConsigneeKey, CTotal,      TTotal,         KTotal,     VTotal,
      STotal,       BTotal,      RTotal,         IDSCompany, IDSAddress1,
      IDSAddress2,  IDSAddress3, C_Company,      C_Address1, C_Address2,
      C_Address3,   DelArea,     DrNum_UsrDf10,  LPAddDate,  DummyLoad, Batch
   FROM #tTempResult
   ORDER BY RowID

   -- Commit all the transaction 
   WHILE @@TRANCOUNT > 0 
      COMMIT TRAN 

   -- Recreate new trancount for PowerBuilder, otherwise will getting PB Runtime error
   WHILE @nTransCount > @@TRANCOUNT 
      BEGIN TRAN 
         
END

GO