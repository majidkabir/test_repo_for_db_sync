SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/          
/* Store procedure: rdt_593Print32                                         */          
/*                                                                         */          
/* Modifications log:                                                      */          
/*                                                                         */          
/* Date       Rev  Author     Purposes                                     */          
/* 2021-03-09 1.0  Chermaine  WMS-16510 Created (dup rdt_593PrintUA01)     */        
/***************************************************************************/          
          
CREATE PROC [RDT].[rdt_593Print32] (          
   @nMobile    INT,          
   @nFunc      INT,          
   @nStep      INT,          
   @cLangCode  NVARCHAR( 3),          
   @cStorerKey NVARCHAR( 15),          
   @cOption    NVARCHAR( 1),          
   @cParam1    NVARCHAR(20),  -- OrderKey       
   @cParam2    NVARCHAR(20),        
   @cParam3    NVARCHAR(20),           
   @cParam4    NVARCHAR(20),          
   @cParam5    NVARCHAR(20),          
   @nErrNo     INT OUTPUT,          
   @cErrMsg    NVARCHAR( 20) OUTPUT          
)          
AS          
   SET NOCOUNT ON              
   SET ANSI_NULLS OFF              
   SET QUOTED_IDENTIFIER OFF              
   SET CONCAT_NULL_YIELDS_NULL OFF           
          
   DECLARE @b_Success     INT          
             
   DECLARE @cDataWindow   NVARCHAR( 50)        
         , @cManifestDataWindow NVARCHAR( 50)        
               
   DECLARE @cTargetDB     NVARCHAR( 20)          
   DECLARE @cLabelPrinter NVARCHAR( 10)          
   DECLARE @cPaperPrinter NVARCHAR( 10)          
   DECLARE @cUserName     NVARCHAR( 18)           
   DECLARE @cLabelType    NVARCHAR( 20)                             
      
   DECLARE 
   @cCartonID     NVARCHAR(20),
   @cLight        NVARCHAR( 1),
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cLOC          NVARCHAR(10),
   @cSKU          NVARCHAR(20),
   @nQTY          INT,
   @cStation1     NVARCHAR(10),
   @cMethod       NVARCHAR(1),
   @cNewCartonID  NVARCHAR( 20), 
   @cScanID       NVARCHAR(20),
   @nFocusParam       INT,      
   @nTranCount        INT      
    
   SELECT @cLabelPrinter = Printer      
         ,@cUserName     = UserName      
         ,@cPaperPrinter = Printer_Paper      
         ,@cFacility     = Facility    
         ,@nInputKey     = InputKey    
   FROM rdt.rdtMobrec WITH (NOLOCK)      
   WHERE Mobile = @nMobile      

   IF @cOption ='1'      
   BEGIN      
      SET @cLOC      = @cParam1      
      SET @cMethod   = '1'
         -- Get carton ID, base on LOC
         SELECT @cCartonID = CartonID
		       ,@cStation1 = STATION
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)
         WHERE Station IN( 'LVSPTL1','LVSPTL2')
            AND LOC = @cLOC

         IF @@ROWCOUNT > 1
         BEGIN
            SET @nErrNo = 164451
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOCMultiCarton
            GOTO Quit
         END
         
         -- Check LOC on station
         IF @cCartonID = ''
         BEGIN
            SET @nErrNo = 164452
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC No Carton
            GOTO Quit
         END

		If exists(select 1 from packdetail(nolock) where labelno = @cCartonID and storerkey = @cStorerKey)
      BEGIN
         -- Print label
         EXEC rdt.rdt_PTLStation_PrintLabel @nMobile, '805', @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CLOSECARTON'
            ,@cStation1
            ,''
            ,''
            ,''
            ,''
            ,@cMethod
            ,@cCartonID
            ,@nErrNo     OUTPUT
            ,@cErrMsg    OUTPUT
   
         IF @nErrNo <> 0
            GOTO Quit
      END
   END      
   GOTO QUIT         
                
--RollBackTran:            
--   ROLLBACK TRAN rdt_593Print32 -- Only rollback change made here            
--   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam      
      
       
Quit:            
   --WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started            
   --   COMMIT TRAN rdt_593Print32          
   --EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam       

GO