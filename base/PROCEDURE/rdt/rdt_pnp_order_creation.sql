SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PnP_Order_Creation                              */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pick and Pack Order Creation                                */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 05-Aug-2013 1.0  James       Created                                 */
/* 13-Jan-2014 1.1  James       Bug fix on checking inventory (james01) */
/************************************************************************/

CREATE PROC [RDT].[rdt_PnP_Order_Creation] (
   @nMobile                   INT,
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3),
   @cFacility                 NVARCHAR( 5),
   @cStorerkey                NVARCHAR( 15),
   @cConsigneeKey             NVARCHAR( 15),
   @cSKU                      NVARCHAR( 20),
   @nQty                      INT, 
   @cLabelNo                  NVARCHAR( 20),
   @cDOID                     NVARCHAR( 20),
   @cType                     NVARCHAR( 1),
   @cCartonType               NVARCHAR( 10),
   @cOrderKey                 NVARCHAR( 10)     OUTPUT,
   @bSuccess                  INT               OUTPUT,
   @nErrNo                    INT               OUTPUT,
   @cErrMsg                   NVARCHAR( 20)     OUTPUT   -- screen limitation, 20 NVARCHAR max
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @cExternOrderKey     NVARCHAR( 30), 
            @cSectionKey         NVARCHAR( 10), 
            @cUserDefine02       NVARCHAR( 20), 
            @cLoadKey            NVARCHAR( 10), 
            @cC_contact1         NVARCHAR( 30), 
            @cC_Contact2         NVARCHAR( 30), 
            @cC_Company          NVARCHAR( 45), 
            @cC_Address1         NVARCHAR( 45), 
            @cC_Address2         NVARCHAR( 45), 
            @cC_Address3         NVARCHAR( 45), 
            @cC_Address4         NVARCHAR( 45), 
            @cC_City             NVARCHAR( 45), 
            @cC_State            NVARCHAR( 45), 
            @cC_Zip              NVARCHAR( 18), 
            @cC_Country          NVARCHAR( 30), 
            @cC_ISOCntryCode     NVARCHAR( 10), 
            @cC_Phone1           NVARCHAR( 18), 
            @cC_Phone2           NVARCHAR( 18), 
            @cC_Fax1             NVARCHAR( 18), 
            @cC_Fax2             NVARCHAR( 18), 
            @cC_vat              NVARCHAR( 18),  
            @cLoadLineNumber     NVARCHAR( 5),  
            @cStatus             NVARCHAR( 10),  
            @cPickSlipNo         NVARCHAR( 10),
            @cPackKey            NVARCHAR( 10),
            @cUserDefine05       NVARCHAR( 18),
            @cUserDefine08       NVARCHAR( 18),
            @cUserDefine09       NVARCHAR( 18),
            @cUserDefine10       NVARCHAR( 18),
            @cCartonGroup        NVARCHAR( 10),
            @cOrderLineNumber    NVARCHAR( 5),
            @cDefaultAllocLOC    NVARCHAR( 10),
            @cLLI_LOT            NVARCHAR( 10), 
            @cLLI_LOC            NVARCHAR( 10), 
            @cPickDetailKey      NVARCHAR( 10), 
            @cLLI_ID             NVARCHAR( 18), 
            @cRoute              NVARCHAR( 10), 
            @cOrderRefNo         NVARCHAR( 10), 
            @cPickDetail_OrdKey  NVARCHAR( 10), 
            @cPickDetail_OrdDtl  NVARCHAR( 5),   
            @nTranCount          INT, 
            @nErr                INT, 
            @nPackQty            INT, 
            @nQTYAVAILABLE       INT, 
            @nQty2Alloc          INT, 
            @nCartonNo           INT 
            
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN
   SAVE TRAN NEW_ORDERS
   
   -- Decide where to go
   IF ISNULL( @cType, '') = 'H'
      GOTO ORD_HEADER
   ELSE  
      GOTO ORD_DETAIL

   -- Insert order header
   ORD_HEADER:
   BEGIN
      SELECT @cSectionKey = '', @cUserDefine02 = '', @cUserDefine10 = '', @cLoadKey = ''
      SET @cSectionKey = SUBSTRING( @cLabelNo, 9, 1)
      SET @cUserDefine02 = SUBSTRING( @cLabelNo, 10, 1)
      SELECT @cUserDefine10 = Long 
      FROM dbo.CodeLkUp WITH (NOLOCK) 
      WHERE ListName = 'ITXWH'
      AND  Code = @cFacility
      AND  StorerKey = @cStorerKey

      SELECT 
         @cC_contact1      = Contact1, 
         @cC_Contact2      = Contact2, 
         @cC_Company       = Company, 
         @cC_Address1      = Address1, 
         @cC_Address2      = Address2,
         @cC_Address3      = Address3,
         @cC_Address4      = Address4,
         @cC_City          = City, 
         @cC_State         = State, 
         @cC_Zip           = Zip, 
         @cC_Country       = Country, 
         @cC_ISOCntryCode  = ISOCntryCode, 
         @cC_Phone1        = Phone1, 
         @cC_Phone2        = Phone2, 
         @cC_Fax1          = Fax1, 
         @cC_Fax2          = Fax2, 
         @cC_vat           = Vat
      FROM dbo.Storer WITH (NOLOCK) 
      WHERE StorerKey = 'ITX' + @cConsigneeKey

      SET @cExternOrderKey = ''
      SET @cExternOrderKey = RTRIM( @cDOID) + @cConsigneeKey + SUBSTRING( @cLabelNo, 9,2)

      SET @cStatus = ''
      SELECT @cOrderKey = OrderKey, 
             @cLoadKey =  LoadKey, 
             @cStatus = Status 
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
      AND   ExternOrderKey = @cExternOrderKey

      IF ISNULL( @cLoadKey, '') = ''
         SELECT @cLoadKey = MAX( LoadKey) 
         FROM dbo.Orders WITH (NOLOCK) 
         WHERE Buyerpo = RTRIM( @cDOID) 
         AND   SectionKey = SUBSTRING( @cLabelNo, 9, 1) 
         AND   Status < '5'
         AND   StorerKey = @cStorerKey
      
      -- If externorderkey exists
      IF ISNULL( @cStatus, '') <> ''
      BEGIN
         IF @cStatus >= '5'
         BEGIN
            SET @nErrNo = 82001
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'ORD PICK CFM'
            GOTO Quit
         END   
      END         
      ELSE  -- Externorderkey not exists, create a new order
      BEGIN
         SELECT @cOrderKey = '', @bSuccess = 0
         EXECUTE nspg_GetKey  
            'ORDER',  
            10,  
            @cOrderKey   OUTPUT,  
            @bSuccess    OUTPUT,  
            @nErr        OUTPUT,  
            @cErrMsg     OUTPUT  

         IF NOT @bSuccess = 1  
         BEGIN  
            SET @nErrNo = 82002
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INS ORD FAIL'
            GOTO RollBackTran
         END  

         INSERT INTO dbo.Orders 
         (OrderKey, StorerKey, ConsigneeKey, ExternOrderKey, BuyerPO, SectionKey, UserDefine02, UserDefine10, Loadkey, 
          C_contact1, C_Contact2, C_Company, C_Address1, C_Address2, C_Address3, C_Address4, C_City, C_State, C_Zip, C_Country, 
          C_ISOCntryCode, C_Phone1, C_Phone2, C_Fax1, C_Fax2, C_vat, Status, Door, Route, Stop, ContainerQty, Facility, Issued, SpecialHandling) 
          VALUES 
         (@cOrderKey, @cStorerKey, 'ITX' + @cConsigneeKey, @cExternOrderKey, RTRIM( @cDOID), @cSectionKey, @cUserDefine02, @cUserDefine10, @cLoadKey, 
          @cC_contact1, @cC_Contact2, @cC_Company, @cC_Address1, @cC_Address2, @cC_Address3, @cC_Address4, @cC_City, @cC_State, @cC_Zip, @cC_Country, 
          @cC_ISOCntryCode, @cC_Phone1, @cC_Phone2, @cC_Fax1, @cC_Fax2, @cC_vat, '0', '99', '99', '99', '0', @cFacility, 'Y', 'N')
          
          IF @@ERROR <> 0
          BEGIN
            SET @nErrNo = 82003
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INS ORD FAIL'
            GOTO RollBackTran
          END
       END
       
--       IF RTRIM(@cDOID) <> 'ITX'
--       BEGIN
      -- Create loadkey if not exists
      IF NOT EXISTS (SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey)
      BEGIN
         SELECT @bSuccess = 0  
         EXECUTE nspg_GetKey  
            'LOADKEY',  
            10,  
            @cLoadkey    OUTPUT,  
            @bSuccess    OUTPUT,  
            @nErr        OUTPUT,  
            @cErrMsg     OUTPUT  

         IF NOT @bSuccess = 1  
         BEGIN  
            SET @nErrNo = 82019
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'GET LKEY FAIL'
            GOTO RollBackTran
         END  
   
         INSERT INTO LoadPlan (LoadKey, Facility, SuperOrderFlag, Priority)  
         VALUES  
         (@cLoadkey, @cFacility, 'N', '9')  
         
         IF @@ERROR <> 0
         BEGIN  
            SET @nErrNo = 82020
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INS LOAD FAIL'
            GOTO RollBackTran
         END  
      END
--         if suser_sname() = 'james'
--            goto quit
      IF NOT EXISTS (SELECT 1 FROM dbo.LoadPlanDetail WITH (NOLOCK) WHERE LoadKey = @cLoadKey AND OrderKey = @cOrderKey)
      BEGIN
         -- Insert Loadplandetail
         SET @cLoadLineNumber = ''
         SELECT @cLoadLineNumber = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LoadLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)  
         FROM dbo.LoadPlanDetail WITH (NOLOCK)  
         WHERE LoadKey = @cLoadKey  
            
         INSERT INTO LOADPLANDETAIL  
         (LoadKey, LoadLineNumber, OrderKey, ConsigneeKey,  ExternOrderKey, [STATUS])  
         VALUES
         (@cLoadKey, @cLoadLineNumber, @cOrderKey, 'ITX' + @cConsigneeKey, @cExternOrderKey,   '0')  

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 82004
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INS LPD FAIL'
            GOTO RollBackTran
         END
      END
--      END

      GOTO Quit
   END
   
   -- Insert order detail
   ORD_DETAIL:
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM dbo.Orders WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND OrderKey = @cOrderKey)
      BEGIN
         SET @nErrNo = 82006
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'ORD NOT EXISTS'
         GOTO RollBackTran
      END             
      
      IF ISNULL( @cSKU, '') = ''
      BEGIN
         SET @nErrNo = 82007
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'BLANK SKU'
         GOTO RollBackTran
      END             
      
      IF @nQty <= 0
      BEGIN
         SET @nErrNo = 82008
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INVALID QTY'
         GOTO RollBackTran
      END             

      SET @cLoadKey = ''
      SELECT @cLoadKey = LoadKey 
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
      AND   OrderKey = @cOrderKey
      
      IF ISNULL(@cLoadKey, '') = ''
      BEGIN
         SELECT @cLoadKey = MAX( LoadKey) 
         FROM dbo.Orders WITH (NOLOCK) 
         WHERE Buyerpo = RTRIM( @cDOID) 
         AND   SectionKey = SUBSTRING( @cLabelNo, 9, 1) 
         AND   Status < '5'
         AND   StorerKey = @cStorerKey

         -- Create loadkey if not exists
         IF NOT EXISTS (SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey)
         BEGIN
            SELECT @bSuccess = 0  
            EXECUTE nspg_GetKey  
               'LOADKEY',  
               10,  
               @cLoadkey    OUTPUT,  
               @bSuccess    OUTPUT,  
               @nErr        OUTPUT,  
               @cErrMsg     OUTPUT  

            IF NOT @bSuccess = 1  
            BEGIN  
               SET @nErrNo = 82019
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'GET LKEY FAIL'
               GOTO RollBackTran
            END  
         END
         
         UPDATE dbo.Orders WITH (ROWLOCK) SET 
            LoadKey = @cLoadkey
         WHERE StorerKey = @cStorerKey 
         AND   OrderKey = @cOrderKey

         IF @@ERROR <> 0
         BEGIN  
            SET @nErrNo = 82022
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'UPD LOAD FAIL'
            GOTO RollBackTran
         END  

         IF NOT EXISTS (SELECT 1 FROM dbo.LoadPlanDetail WITH (NOLOCK) WHERE LoadKey = @cLoadKey AND OrderKey = @cOrderKey)
         BEGIN
            SELECT @cConsigneeKey = ConsigneeKey, 
                   @cExternOrderKey = ExternOrderKey 
            FROM dbo.Orders WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey 
            AND   OrderKey = @cOrderKey
            
            -- Insert Loadplandetail
            SET @cLoadLineNumber = ''
            SELECT @cLoadLineNumber = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LoadLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)  
            FROM dbo.LoadPlanDetail WITH (NOLOCK)  
            WHERE LoadKey = @cLoadKey  
               
            INSERT INTO LOADPLANDETAIL  
            (LoadKey, LoadLineNumber, OrderKey, ConsigneeKey,  ExternOrderKey, [STATUS])  
            VALUES
            (@cLoadKey, @cLoadLineNumber, @cOrderKey, @cConsigneeKey, @cExternOrderKey,   '0')  

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 82023
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INS LPD FAIL'
               GOTO RollBackTran
            END
         END
      END             
      
      SELECT @cPackKey = '', @cUserDefine05 = '', @cUserDefine08 = '', @cUserDefine09 = '', @cUserDefine10 = ''
      SELECT @cPackKey = PackKey, 
             @cUserDefine05 = SUSR2, 
             @cUserDefine08 = SUSR5, 
             @cUserDefine09 = SUSR4, 
             @cUserDefine10 = SUSR3, 
             @cCartonGroup  = CartonGroup 
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cSKU

      IF NOT EXISTS (SELECT 1 FROM dbo.OrderDetail WITH (NOLOCK) 
                 WHERE StorerKey = @cStorerKey
                 AND   OrderKey = @cOrderKey
                 AND   SKU = @cSKU
                 AND   [Status] < '5')
      BEGIN
         -- Insert Orderdetail
         SET @cOrderLineNumber = ''
         SELECT @cOrderLineNumber = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( OrderLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)  
         FROM dbo.OrderDetail WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey 
         AND   OrderKey = @cOrderKey 

         INSERT INTO OrderDetail 
        (OrderKey, OrderLineNumber, StorerKey, SKU, OpenQty, UOM, LoadKey, PackKey, Facility, 
         UserDefine01, UserDefine04, UserDefine05, UserDefine08, UserDefine09, UserDefine10, [Status])
         VALUES
        (@cOrderKey, @cOrderLineNumber, @cStorerKey, @cSKU, @nQty, 'EA', @cLoadKey, @cPackKey, @cFacility, 
         '1', 'M', @cUserDefine05, @cUserDefine08, @cUserDefine09, @cUserDefine10, '0')
         
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 82009
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INS ORDTL FAIL'
            GOTO RollBackTran
         END        
      END
      ELSE
      BEGIN
         SET @cOrderLineNumber = ''
         
         SELECT @cOrderLineNumber = OrderLineNumber 
         FROM dbo.OrderDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   OrderKey = @cOrderKey
         AND   SKU = @cSKU
         AND   [Status] < '5'
         AND   UserDefine04 = 'M'
         ORDER BY 1

         -- Only can update to order lines with userdefine04 = M
         IF ISNULL(@cOrderLineNumber, '') = ''
         BEGIN
            -- Insert Orderdetail
            SET @cOrderLineNumber = ''
            SELECT @cOrderLineNumber = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( OrderLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)  
            FROM dbo.OrderDetail WITH (NOLOCK)  
            WHERE StorerKey = @cStorerKey 
            AND   OrderKey = @cOrderKey 

            INSERT INTO OrderDetail 
           (OrderKey, OrderLineNumber, StorerKey, SKU, OpenQty, UOM, LoadKey, PackKey, Facility, 
            UserDefine01, UserDefine04, UserDefine05, UserDefine08, UserDefine09, UserDefine10, [Status])
            VALUES
           (@cOrderKey, @cOrderLineNumber, @cStorerKey, @cSKU, @nQty, 'EA', @cLoadKey, @cPackKey, @cFacility, 
            '1', 'M', @cUserDefine05, @cUserDefine08, @cUserDefine09, @cUserDefine10, '0')
            
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 82009
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INS ORDTL FAIL'
               GOTO RollBackTran
            END        
         END
         ELSE
         BEGIN
            UPDATE dbo.OrderDetail WITH (ROWLOCK) SET 
               OpenQty = OpenQty + @nQty 
            WHERE StorerKey = @cStorerKey
            AND   OrderKey = @cOrderKey
--            AND   SKU = @cSKU
--            AND   [Status] < '5'
            AND   OrderLineNumber = @cOrderLineNumber

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 82024
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'UPD ORDTL FAIL'
               GOTO RollBackTran
            END       
         END
      END
      
      --Allocation
      SET @cDefaultAllocLOC = ''
      SET @cDefaultAllocLOC = rdt.RDTGetConfig( @nFunc, 'DefaultAllocLoc', @cStorerKey)
      
      -- Make sure default allocation loc is a valid loc
      IF ISNULL(@cDefaultAllocLOC, '') = '' OR 
         NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                     WHERE Facility = @cFacility 
                     AND   LOC = @cDefaultAllocLOC)
      BEGIN
         SET @nErrNo = 82010
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INV ALLOC LOC'
         GOTO RollBackTran
      END        

      IF NOT EXISTS (SELECT 1
                     FROM LOTxLOCxID LLI (NOLOCK)
                     JOIN LOC LOC (NOLOCK) ON LLI.LOC = LOC.LOC
                     WHERE LLI.StorerKey = @cStorerKey
                     AND LLI.SKU = @cSKU
                     AND LOC.Facility = @cFacility
                     AND LOC.LOC = @cDefaultAllocLOC   -- must allocate from here
                     AND (LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED) >= @nQty)     -- (james01)
      BEGIN
         SET @nErrNo = 82026
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NOT ENUF INV'
         GOTO RollBackTran
      END        
      
      SET @nPackQty = 0
      
      -- Look for inventory
      DECLARE CURSOR_CANDIDATES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT LLI.LOT, LLI.ID, QTYAVAILABLE = (LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED)
      FROM LOTxLOCxID LLI (NOLOCK)
      JOIN LOC LOC (NOLOCK) ON LLI.LOC = LOC.LOC
      WHERE LLI.StorerKey = @cStorerKey
      AND LLI.SKU = @cSKU
      AND LOC.Facility = @cFacility
      AND LOC.LOC = @cDefaultAllocLOC   -- must allocate from here
      ORDER BY  LLI.Lot
      OPEN CURSOR_CANDIDATES
      FETCH NEXT FROM CURSOR_CANDIDATES INTO @cLLI_LOT, @cLLI_ID, @nQTYAVAILABLE
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @nQTYAVAILABLE > @nQty
            SET @nQty2Alloc = @nQty
         ELSE
            SET @nQty2Alloc = @nQTYAVAILABLE

         -- SAME ORDERKEY + SKU + LOT + LOC + ID
         IF EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                    WHERE OrderKey = @cOrderKey
                    AND   SKU = @cSKU
                    AND   LOT = @cLLI_LOT
                    AND   LOC = @cDefaultAllocLOC
                    AND   ID = @cLLI_ID
                    AND   [STATUS] < '4')
         BEGIN
            SELECT 
               @cPickDetail_OrdKey = OrderKey, 
               @cPickDetail_OrdDtl = OrderLineNumber, 
               @cPickDetailKey = PickDetailKey   
            FROM dbo.PickDetail WITH (NOLOCK) 
            WHERE OrderKey = @cOrderKey
            AND   SKU = @cSKU
            AND   LOT = @cLLI_LOT
            AND   LOC = @cDefaultAllocLOC
            AND   ID = @cLLI_ID
            AND   [STATUS] < '4'

            IF EXISTS (SELECT 1 FROM dbo.OrderDetail WITH (NOLOCK) 
                       WHERE OrderKey = @cPickDetail_OrdKey
                       AND   OrderLineNumber = @cPickDetail_OrdDtl
                       AND   SKU = @cSKU
                       AND   OpenQty > (QtyAllocated + QtyPicked)
                       AND   [STATUS] < '5')
            BEGIN
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                  Qty = Qty + @nQty2Alloc
--               WHERE OrderKey = @cPickDetail_OrdKey
--               AND   OrderLineNumber = @cPickDetail_OrdDtl
--               AND   SKU = @cSKU
--               AND   [STATUS] < '4'
--               AND   LOC = @cDefaultAllocLOC
               WHERE PickDetailKey = @cPickDetailKey
               
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 82025
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'ALLOCATE FAIL'
                  GOTO RollBackTran
               END        
            END
            ELSE
               GOTO ALLOCATE_NEWLINE
         END
         ELSE
         BEGIN
            ALLOCATE_NEWLINE:
            SELECT @cPickDetailKey = '', @bSuccess = 0
            EXECUTE nspg_getkey
                  'PickDetailKey',
                  10,
                  @cPickDetailKey   OUTPUT,
                  @bSuccess         OUTPUT,  
                  @nErr             OUTPUT,  
                  @cErrMsg          OUTPUT  

            IF NOT @bSuccess = 1  
            BEGIN  
               SET @nErrNo = 82011
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'GET PDKEY FAIL'
               GOTO RollBackTran
            END  
         
            INSERT INTO PICKDETAIL 
            (PickDetailKey, PickHeaderKey, CaseID, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, 
             UOM, UOMQty, Qty, Status, Loc, ID, PackKey, CartonGroup)
             VALUES 
             (@cPickDetailKey, '', '', @cOrderKey, @cOrderLineNumber, @cLLI_LOT, @cStorerKey, @cSKU, 
              '6', '1', @nQty2Alloc, '0', @cDefaultAllocLOC, @cLLI_ID, @cPackKey, @cCartonGroup)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 82012
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'ALLOCATE FAIL'
               GOTO RollBackTran
            END        
         END
         
         SET @nQty = @nQty - @nQty2Alloc
         SET @nPackQty = @nPackQty + @nQty2Alloc
         
         IF @nQty <=0
            BREAK
            
         FETCH NEXT FROM CURSOR_CANDIDATES INTO @cLLI_LOT, @cLLI_ID, @nQTYAVAILABLE
      END
      CLOSE CURSOR_CANDIDATES
      DEALLOCATE CURSOR_CANDIDATES

      -- Print pickslip after allocation successful
      -- the pickslip only print after allocation 
      IF NOT EXISTS (SELECT 1 FROM dbo.PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey)
      BEGIN
         EXEC rdt.rdt_PiecePickSlip_size @cLoadKey
      END

      -- Packing
      SET @cPickSlipNo = ''
      SELECT @cPickSlipNo = PickHeaderKey 
      FROM dbo.PickHeader WITH (NOLOCK) 
      WHERE OrderKey = @cOrderKey
      
      IF ISNULL(@cPickSlipNo, '') = ''
      BEGIN
         SET @nErrNo = 82013
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NO PSLIP FOUND'
         GOTO RollBackTran
      END       

      -- Scan in
      IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
      BEGIN
         INSERT INTO PickingInfo
         (PickSlipNo, ScanInDate, PickerID) VALUES (@cPickSlipNo, GETDATE(), sUser_sName())

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 82021
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'SCAN IN FAIL'
            GOTO RollBackTran
         END       
      END
      
      -- Create packheader
      IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
      BEGIN
         SELECT @cRoute = [Route], 
                @cOrderRefNo = SUBSTRING( ExternOrderKey, 1, 18), 
                @cConsigneekey = ConsigneeKey 
         FROM dbo.Orders WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey
         AND   StorerKey = @cStorerKey

         INSERT INTO dbo.PackHeader
         (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
         VALUES
         (@cRoute, @cOrderKey, @cOrderRefNo, @cLoadKey, @cConsigneekey, @cStorerKey, @cPickSlipNo)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 82013
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS PKHDR FAIL'
            GOTO RollBackTran
         END 
      END

      -- Create packdetail if not exists pickslipno + label no + sku; else update qty
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                     WHERE PickSlipNo = @cPickSlipNo 
                     AND   LabelNo = @cLabelNo
                     AND   SKU = @cSKU)
      BEGIN
         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate)
         VALUES
            (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSKU, @nPackQty,
            @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 82015
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'
            GOTO RollBackTran
         END 
      END
      ELSE
      BEGIN
         UPDATE dbo.PackDetail WITH (ROWLOCK) SET 
            Qty = Qty + @nPackQty 
         WHERE StorerKey = @cStorerKey
         AND   PickSlipNo = @cPickSlipNo
         AND   LabelNo = @cLabelNo
         AND   SKU = @cSKU

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 82016
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
            GOTO RollBackTran
         END 
      END
      
      SELECT TOP 1 @nCartonNo = CartonNo
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   PickSlipNo = @cPickSlipNo
      AND   LabelNo = @cLabelNo
      
      
      -- Insert carton type
      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) 
                     WHERE PickSlipNo = @cPickSlipNo
                     AND   CartonNo = @nCartonNo)
      BEGIN
         INSERT INTO dbo.PACKINFO (PickSlipNo, CartonNo, CartonType)  
         VALUES (@cPickSlipNo, @nCartonNo, @cCartonType)   

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 82017
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
            GOTO RollBackTran
         END 
      END
      ELSE
      BEGIN
         UPDATE dbo.PackInfo WITH (ROWLOCK) SET 
            CartonType = @cCartonType 
         WHERE PickSlipNo = @cPickSlipNo
         AND   CartonNo = @nCartonNo
         --AND   ISNULL(CartonType, '') = ''

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 82018  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PINFO FAIL  
            GOTO RollBackTran  
         END    
      END
   END
   
   GOTO Quit
   
   RollBackTran:
      ROLLBACK TRAN NEW_ORDERS

   Quit:
   WHILE @@TRANCOUNT > @nTranCount  
      COMMIT TRAN NEW_ORDERS 

END

GO