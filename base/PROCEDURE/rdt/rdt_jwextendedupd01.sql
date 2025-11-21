SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_JWExtendedUpd01                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Inditex specific update to ASN                              */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 29-05-2014  1.0  James       SOS311987 - Created                     */
/* 13-09-2014  1.1  James       SOS320518 - Update parcel id to OD.UDF05*/
/*                              for C&C orders (james01)                */
/* 25-Sep-2014 1.2  James       SOS321520 - Update O.Userdefine10 with  */
/*                              value from codelkup (james02)           */
/* 08-Oct-2014 1.3  James       SOS322524 - Enhancement. Trigger        */
/*                              PACKSOLOG only when pick=pack (james03) */
/************************************************************************/

CREATE PROC [RDT].[rdt_JWExtendedUpd01] (
   @nMobile                   INT,          
   @nFunc                     INT,          
   @cLangCode                 NVARCHAR( 3),  
   @nStep                     INT, 
   @nInputKey                 INT, 
   @cStorerkey                NVARCHAR( 15), 
   @cOrderkey                 NVARCHAR( 10), 
   @cSku                      NVARCHAR( 20), 
   @cToteNo                   NVARCHAR( 18), 
   @cDropIDType               NVARCHAR( 10), 
   @cPrevOrderkey             NVARCHAR( 10), 
   @nErrNo                    INT           OUTPUT,  
   @cErrMsg                   NVARCHAR( 20) OUTPUT    

)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_PACKSOLOGITF NVARCHAR( 1), 
           @n_TranCount    INT, 
           @b_success      INT, 
           @n_err          INT,  
           @c_errmsg       NVARCHAR( 250)  

   DECLARE @cSingles       NVARCHAR( 10),            
           @cDoubles       NVARCHAR( 10),            
           @cMultis        NVARCHAR( 10), 
           @cTOrderKey     NVARCHAR( 10), 
           @nTotalPickQty  INT,        
           @nTotalPackQty  INT        
           
   DECLARE @cIncoTerm      NVARCHAR( 10), 
           @cCCParcelID    NVARCHAR( 8), 
           @nTranCount     INT, 
           @cShort         NVARCHAR( 10), 
           @cPickSlipNo    NVARCHAR( 10) 

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_JWExtendedUpd01
   
   SELECT @cIncoTerm = ISNULL(RTRIM(IncoTerm),'')  
   FROM  ORDERS WITH (NOLOCK)  
   WHERE Orderkey = @cOrderkey  
      
   -- (james01)
   IF EXISTS (SELECT 1 FROM dbo.Codelkup WITH (NOLOCK) WHERE Listname = 'SHIPPING' AND Code = @cIncoTerm AND UDF01 = 'C&C')      
   BEGIN

      EXECUTE dbo.nspg_GetKey  
         'CCParcelID',  
         8,  
         @cCCParcelID   OUTPUT,  
         @b_success     OUTPUT,  
         @n_err         OUTPUT,  
         @c_errmsg      OUTPUT  

      IF ISNULL( @cCCParcelID, '') = ''
      BEGIN
         SET @nErrNo = @n_err
         SET @cErrMsg = @c_errmsg
         GOTO RollBackTran 
      END
      ELSE
      BEGIN
         IF @cCCParcelID = '99999999'
         BEGIN
            UPDATE NCOUNTER WITH (ROWLOCK) SET 
               KeyCount = 30000000
            WHERE KeyName = 'CCParcelID'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = @n_err
               SET @cErrMsg = @c_errmsg
               GOTO RollBackTran 
            END
         END
         ELSE
         BEGIN
            IF CAST( @cCCParcelID AS INT) < 30000001 OR CAST( @cCCParcelID AS INT) > 99999999
            BEGIN
               UPDATE NCOUNTER WITH (ROWLOCK) SET 
                  KeyCount = 30000001
               WHERE KeyName = 'CCParcelID'

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = @n_err
                  SET @cErrMsg = @c_errmsg
                  GOTO RollBackTran 
               END

               SET @cCCParcelID = '30000001'
            END
         END
      END

      UPDATE OD WITH (ROWLOCK) SET 
         UserDefine05 = @cCCParcelID, 
         Trafficcop = NULL 
      FROM dbo.OrderDetail OD 
      JOIN dbo.Orders O ON ( OD.OrderKey = O.OrderKey)
      JOIN dbo.PackHeader PH ON ( O.OrderKey = PH.OrderKey)
      JOIN dbo.PackDetail PD ON ( PH.PickSlipNo = PD.PickSlipNo AND OD.SKU = PD.SKU)
      WHERE O.StorerKey = @cStorerKey
      AND   O.OrderKey = @cOrderkey
      AND   PD.LabelNo = 'CC' + RTRIM( @cOrderkey) + 'CC'
      
      IF @@ERROR <> 0
         GOTO RollBackTran

      -- (james02)
      SET @cShort = ''
      SELECT @cShort = Short FROM dbo.CodelkUp WITH (NOLOCK) WHERE ListName = 'ParcelProv' and Code = @cIncoTerm 

      IF ISNULL( @cShort, '') <> ''
      BEGIN
         UPDATE dbo.Orders WITH (ROWLOCK) SET 
            UserDefine10 = @cShort
         WHERE StorerKey = @cStorerKey
         AND   OrderKey = @cOrderkey
         AND   IncoTerm = @cIncoTerm

         IF @@ERROR <> 0
            GOTO RollBackTran
      END

      SELECT @cPickSlipNo = PickSlipNo 
      FROM dbo.PackHeader WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   OrderKey = @cOrderkey

      UPDATE dbo.PackDetail WITH (ROWLOCK) SET 
         Refno = LabelNo, 
         ArchiveCop = NULL
      WHERE PickSlipNo = @cPickSlipNo
      AND   StorerKey = @cStorerKey
      AND   ISNULL( Refno, '') = '' 
      AND   LabelNo = 'CC' + RTRIM( @cOrderkey) + 'CC'

      IF @@ERROR <> 0
         GOTO RollBackTran

   END

   -- check if total order fully despatched  (james03)
   SELECT @nTotalPickQty = SUM(ISNULL(PK.Qty,0))   
   FROM  dbo.PICKDETAIL PK WITH (nolock)  
   WHERE PK.StorerKey = @cStorerKey
   AND   PK.Orderkey = @cOrderkey  
           
   SELECT @nTotalPackQty = SUM(ISNULL(PD.Qty,0))  
   FROM  dbo.PACKDETAIL PD WITH (NOLOCK)  
   JOIN  dbo.PACKHEADER PH WITH (NOLOCK) ON (PD.PickslipNo = PH.PickSlipNo)
   WHERE PH.StorerKey = @cStorerKey
   AND   PH.Orderkey = @cOrderkey 

   IF @nTotalPickQty = @nTotalPackQty  
   BEGIN
      SELECT @c_PACKSOLOGITF = 0, @b_success = 0    

      -- Check whether the config is turned on
      EXECUTE nspGetRight 
            NULL,                   -- facility    
            @cStorerkey,            -- Storerkey    
            NULL,                   -- Sku    
            'PACKSOLOG',            -- Configkey    
            @b_success        OUTPUT,    
            @c_PACKSOLOGITF   OUTPUT,    
            @n_err            OUTPUT,    
            @c_errmsg         OUTPUT    

      IF @b_success <> 1    
      BEGIN
         SET @nErrNo = @n_err
         SET @cErrMsg = @c_errmsg
         GOTO RollBackTran 
      END

      -- If config not turned on then no need proceed
      IF ISNULL( @c_PACKSOLOGITF, '') <> '1'
         GOTO Quit

      SET @cSingles     = 'SINGLES' -- 1 orders 1 sku
      SET @cDoubles     = 'DOUBLES' -- 1 orders 2 sku
      SET @cMultis      = 'MULTIS'  -- 1 orders multi sku
      SET @cDropIDType  = ''      
      SET @cTOrderKey = ''      

      SELECT @cDropIDType  = ISNULL(RTRIM(DropIDType),'')            
      FROM dbo.DROPID WITH (NOLOCK)             
      WHERE DropId = @cToteno 

      IF ISNULL( @cOrderkey, '') <> ''
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.OrderDetail WITH (NOLOCK)
                     WHERE OrderKey = @cOrderkey
                     AND   StorerKey = @cStorerkey
                     AND   QtyPicked = 0)
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.TransmitLog3 WITH (NOLOCK) 
                            WHERE TableName = 'PACKSOLOG'
                            AND   Key1 = @cOrderkey
                            AND   Key3 = @cStorerkey)
            BEGIN
               -- Insert transmitlog3 here
               EXEC ispGenTransmitLog3 'PACKSOLOG', @cOrderkey, '', @cStorerkey, '' -- Added in DocType to determine Return/Normal Receipt    
               , @b_success OUTPUT    
               , @n_err OUTPUT    
               , @c_errmsg OUTPUT    
           
               IF @b_success <> 1    
               BEGIN    
                  SET @nErrNo = @n_err   
                  SET @cErrMsg = @c_errmsg 
                  GOTO RollBackTran    
               END    
            END
         END
      END
   END

   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_JWExtendedUpd01  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  
END

GO