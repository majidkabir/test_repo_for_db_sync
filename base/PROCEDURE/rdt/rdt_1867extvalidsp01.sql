SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1867ExtValidSP01                                */    
/* Purpose: Validate cart id prefix value                               */    
/*                 For HUSQ                                             */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */ 
/* 2024-10-10   1.0  JHU151    FCR-777 Created                          */ 
/************************************************************************/    
    
CREATE   PROC rdt.rdt_1867ExtValidSP01 (    
   @nMobile        INT,  
   @nFunc          INT,  
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,  
   @nInputKey      INT,  
   @cFacility      NVARCHAR( 5),  
   @cStorerKey     NVARCHAR( 15),  
   @cGroupKey      NVARCHAR( 10),  
   @cTaskDetailKey NVARCHAR( 10),  
   @cPickZone      NVARCHAR( 10),  
   @cCartId        NVARCHAR( 10),  
   @cMethod        NVARCHAR( 1),  
   @cFromLoc       NVARCHAR( 10),  
   @cCartonId      NVARCHAR( 20),  
   @cSKU           NVARCHAR( 20),  
   @nQty           INT,  
   @cOption        NVARCHAR( 1),  
   @cToLOC         NVARCHAR( 10),  
   @tExtValidate   VariableTable READONLY,  
   @nErrNo         INT           OUTPUT,  
   @cErrMsg        NVARCHAR( 20) OUTPUT  
)    
AS    
   SET NOCOUNT ON         
   SET QUOTED_IDENTIFIER OFF         
   SET ANSI_NULLS OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF     
    
   DECLARE @cPickMethod    NVARCHAR( 10)  
   DECLARE @cCartonType    NVARCHAR( 10)  
   DECLARE @cUserName      NVARCHAR( 18)  
   DECLARE @cCode          NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cSalesMan      NVARCHAR( 30)  
   DECLARE @cInField06     NVARCHAR( 60)
   DECLARE @cErrMsg1       NVARCHAR( 20)
   DECLARE @cErrMsg2       NVARCHAR( 20)
   DECLARE @nSuggQty       INT = 0
   DECLARE @nActQTY        INT = 0
   
   DECLARE @cConsigneeKey     NVARCHAR( 15)
   DECLARE @cCZip             NVARCHAR( 18)
   DECLARE @cSUSR1            NVARCHAR( 20)
   DECLARE @cSUSR3            NVARCHAR( 20)
   DECLARE @cSUSR4            NVARCHAR( 20)
   DECLARE @cPickDetailKey    NVARCHAR( 18)
   DECLARE @fTotalCube        float
   DECLARE @fTotalWeight      float

   DECLARE @fCurrentTotalCube        float
   DECLARE @fCurrentTotalWeight      float
   DECLARE @cOriCartonId         NVARCHAR(20)
   DECLARE @nRowCount         INT
   DECLARE @nTranCount        INT


   SELECT @cUserName = UserName  
   FROM rdt.RDTMOBREC WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
     
   IF @nStep = 5  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         IF @cMethod = '3'
         BEGIN
            SELECT
               @cOrderKey = TD.OrderKey,
               @cConsigneeKey = ORD.ConsigneeKey,
               @cCZip = ORD.C_Zip
            FROM TaskDetail TD WITH(NOLOCK)
            INNER JOIN ORDERS ORD WITH(NOLOCK) ON TD.OrderKey = ORD.OrderKey AND TD.StorerKey = ORD.Storerkey
            WHERE TD.StorerKey = @cStorerKey
            AND TD.groupkey = @cGroupkey
            --AND TD.DropID = @cCartonID
            -- TD.Sku = @cSKU

            SELECT 
               @fTotalCube = ISNULL(SUM(WidthUOM3 * LengthUOM3 * HeightUOM3 * PKD.QTY),0),
               @fTotalWeight = ISNULL(SUM(STDGROSSWGT * PKD.Qty),0)
            FROM SKU sku WITH(NOLOCK)
            INNER JOIN PACK pack WITH(NOLOCK) ON sku.PackKey = pack.PackKey
            INNER JOIN PickDetail PKD WITH(NOLOCK) ON sku.Sku = PKD.SKU
            WHERE PKD.StorerKey = @cStorerKey
            AND PKD.DropID = @cCartonID
            AND PKD.OrderKey = @cOrderKey


            SELECT 
               @fCurrentTotalCube = ISNULL(SUM(WidthUOM3 * LengthUOM3 * HeightUOM3 * PKD.QTY),0),
               @fCurrentTotalWeight = ISNULL(SUM(STDGROSSWGT * PKD.Qty),0),
               @cOriCartonId = MAX(PKD.DropID)
            FROM SKU sku WITH(NOLOCK)
            INNER JOIN PACK pack WITH(NOLOCK) ON sku.PackKey = pack.PackKey
            INNER JOIN PickDetail PKD WITH(NOLOCK) ON sku.Sku = PKD.SKU
            WHERE PKD.StorerKey = @cStorerKey
            --AND PKD.DropID = @
            AND PKD.Status = '5'
            AND PKD.TaskdetailKey = @cTaskdetailKey
            AND PKD.OrderKey = @cOrderKey

            IF @cOriCartonId <> @cCartonID
            BEGIN
               
               SET @fTotalCube = @fTotalCube + @fCurrentTotalCube
               SET @fTotalWeight = @fTotalWeight + @fTotalWeight
            END
            SELECT
               @cSUSR1 = SUSR1,   -- stander carton cube
               @cSUSR3 = SUSR3,   -- stander carton weight
               @cSUSR4 = SUSR4
            FROM Storer WITH(NOLOCK)
            WHERE ConsigneeFor = @cStorerKey
              AND address1 = @cConsigneeKey
              AND Zip = @cCZip
              AND type = '2'

            --(storer.storerkey =’ 0000000001’and storer.type = ‘2’ and
            --storer.consigneefor =’HUSQ’
            IF ISNULL(@cSUSR1,'') = '' OR ISNULL(@cSUSR3,'') = '' OR ISNULL(@cSUSR4,'') = ''
            BEGIN
               SELECT
                  @cSUSR1 = SUSR1,   -- stander carton cube
                  @cSUSR3 = SUSR3,   -- stander carton weight
                  @cSUSR4 = SUSR4
               FROM Storer WITH(NOLOCK)
               WHERE StorerKey = '0000000001'
               AND ConsigneeFor = @cStorerKey
               AND type = '2'
            END

            IF @fTotalCube > CAST(@cSUSR1 AS FLOAT)
            BEGIN
               SET @nErrNo = 227351              
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Exceed Cube      
               GOTO QUIT                 
            END
            
            IF @fTotalWeight > CAST(@cSUSR3 AS FLOAT)
            BEGIN
               SET @nErrNo = 227352              
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Exceed Weight      
               GOTO QUIT                 
            END

            -- not allow mixed in carton
            IF ISNULL(@cSUSR4,'') = 'N'
            BEGIN
               SELECT @nRowCount = COUNT(DISTINCT S.CLASS)  
               FROM PICKDETAIL PKD WITH(NOLOCK)
               INNER JOIN TaskDetail TD WITH(NOLOCK) ON PKD.TaskDetailKey = TD.TaskDetailKey
			      INNER JOIN SKU S WITH(NOLOCK) ON S.Sku = PKD.Sku
               WHERE PKD.StorerKey = @cStorerKey
               AND (PKD.DropID = @cCartonID OR PKD.DropID = @cOriCartonId)
               AND PKD.OrderKey = @cOrderKey
               AND TD.Groupkey = @cGroupkey
               AND PKD.Status = '5'

               -- mutil sku
               IF @nRowCount > 1
               BEGIN
                  SET @nErrNo = 227353              
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Mixed Brand     
                  GOTO QUIT  
               END
            END

            GOTO QUIT
         END         
      END
      IF @nInputKey = 0
      BEGIN
         IF @cMethod = '3'
         BEGIN
            GOTO RollBackPick 
         END
         ELSE
         BEGIN
            SET @nErrNo = 227585                  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Confirm Tote                  
            GOTO QUIT  
         END         
      END
   END

GOTO Quit

RollBackPick:
-- Handling transaction  
SET @nTranCount = @@TRANCOUNT
BEGIN TRAN  -- Begin our own transaction  
SAVE TRAN ConfirmPick 
   UPDATE TaskDetail
   SET [Status] = '3',
      EditDate = GETDATE(),
      EditWho = @cUserName
   WHERE TaskDetailKey = @cTaskdetailKey

   UPDATE PICKDETAIL
   SET [Status] = '0',
       EditWho  = SUSER_SNAME(),
       DropID = '',
       EditDate = GETDATE()
   WHERE TaskDetailKey = @cTaskdetailKey

   IF EXISTS(SELECT 1 FROM PickSerialNo PSN WITH(NOLOCK)
                     INNER JOIN PICKDETAIL PKD WITH(NOLOCK) ON PSN.PickDetailkey = PKD.PickDetailkey                     
               WHERE PKD.TaskDetailKey = @cTaskdetailKey
   )
   BEGIN
      DELETE PickSerialNo
      FROM PICKDETAIL
      JOIN PickSerialNo on PickSerialNo.PickDetailkey = PICKDETAIL.PickDetailkey
      WHERE PICKDETAIL.TaskDetailKey = @cTaskdetailKey
   END

   SET @cPickDetailKey = ''
   WHILE(1=1)
   BEGIN
      SELECT TOP 1
         @cPickDetailKey = PickDetailKey
      FROM PICKDETAIL WITH(NOLOCK)
      WHERE PickDetailkey = @cPickDetailKey
      AND Storerkey = @cStorerkey
      AND PickDetailKey > @cPickDetailKey
      ORDER BY PickDetailKey

      IF @@ROWCOUNT = 0
      BEGIN
         BREAK
      END

      -- Posting to serial no
      UPDATE dbo.SerialNo SET
         Status = '5', 
         EditDate = GETDATE(), 
         EditWho = SUSER_SNAME()
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND SerialNo IN (SELECT SerialNo FROM PickSerialNo WITH(NOLOCK) 
                           WHERE PickDetailKey = @cPickDetailKey
                           AND SKU = @cSKU
                           AND Storerkey = @cStorerkey
                           )
      
      DELETE FROM PickSerialNo 
       WHERE PickDetailKey = @cPickDetailKey
         AND SKU = @cSKU
         AND Storerkey = @cStorerkey 
   END

WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  

Quit:    

GO