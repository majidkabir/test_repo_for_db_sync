SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_JWExtendedUpd05                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Add PACKSOLOG into TL3 if any orderdetail with qtypicked = 0*/
/*          Work for Ecom orders only                                   */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 11-18-2014  1.0  James       SOS326139 - Created                     */
/* 01-27-2015  1.1  James       Change variable len for @cToteNo from   */
/*                              18 to 20 (james01)                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_JWExtendedUpd05] (
   @nMobile                   INT, 
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3), 
   @nStep                     INT, 
   @nInputKey                 INT, 
   @cStorerkey                NVARCHAR( 15), 
   @cMbolKey                  NVARCHAR( 10), 
   @cToteNo                   NVARCHAR( 20),    -- (james01)
   @cOption                   NVARCHAR( 10), 
   @cOrderkey                 NVARCHAR( 10), 
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

   DECLARE @nTotalPickQty  INT,        
           @nTotalPackQty  INT        
           
   SET @n_TranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_JWExtendedUpd05

   -- If not ecom orders then quit
   IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                   WHERE StorerKey = @cStorerKey
                   AND   OrderKey = @cOrderkey
                   AND   UserDefine01 <> '')
      GOTO Quit

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
         ROLLBACK TRAN rdt_JWExtendedUpd05  
   Quit:  
      WHILE @@TRANCOUNT > @n_TranCount  
         COMMIT TRAN  
END

GO