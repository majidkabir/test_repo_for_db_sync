SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/          
/* Store procedure: rdt_593PrintDW02                                       */          
/*                                                                         */          
/* Modifications log:                                                      */          
/*                                                                         */          
/* Date       Rev  Author   Purposes                                       */          
/* 2023-10-27 1.0  James    WMS-23933. Modified from rdt_593PrintDW01      */        
/***************************************************************************/          
          
CREATE   PROCEDURE [RDT].[rdt_593PrintDW02] (          
   @nMobile    INT,          
   @nFunc      INT,          
   @nStep      INT,          
   @cLangCode  NVARCHAR( 3),          
   @cStorerKey NVARCHAR( 15),          
   @cOption    NVARCHAR( 1),          
   @cParam1    NVARCHAR(20),  -- Loadkey       
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
          
   DECLARE @b_Success      INT, 
           @n_Err          INT, 
           @c_ErrMsg       NVARCHAR( 20)          
      
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
   @nTranCount        INT,      
   @cLoadkey      NVARCHAR(10),
   @cTaskBatchNo  NVARCHAR(10),
   @cPickSlipno   NVARCHAR(10),
   @cPickSlipno_Conso NVARCHAR(10)

	     
   SELECT @cLabelPrinter = Printer      
         ,@cUserName     = UserName      
         ,@cPaperPrinter   = Printer_Paper      
         ,@cFacility       = Facility    
         ,@nInputKey       = InputKey    
   FROM rdt.rdtMobrec WITH (NOLOCK)      
   WHERE Mobile = @nMobile      

   SET @nTranCount = @@TRANCOUNT          
             
   BEGIN TRAN          
   SAVE TRAN rdt_593PrintDW02         
   
   IF @cOption ='3'      
   BEGIN      
      SET @cLoadkey = @cParam1
	  
	   EXECUTE nsp_GetPickSlipOrders04 
	      @c_loadkey =  @cLoadkey
      
      EXECUTE isp_batching_task_summary
         @c_Loadkey     = @cLoadkey, 
         @c_OrderCount  = '9999',
         @c_Pickzone    = 'ALL', 
         @c_Mode        = '1', 
         @c_ReGen       = '', 
         @c_updatepick  = 'N'
           
      SELECT @cTaskBatchNo = PT.taskbatchno 
      FROM dbo.PackTask PT WITH (NOLOCK)
      JOIN dbo.LoadPlanDetail LP WITH (NOLOCK) ON ( PT.Orderkey = LP.Orderkey) 
      WHERE LP.LoadKey = @cLoadkey
      
      EXECUTE isp_Batching_AssignCart 
         @c_TaskBatchNo   = @cTaskBatchNo,
         @b_Success       = @b_Success OUTPUT,      
         @n_Err           = @n_Err     OUTPUT,  
         @c_ErrMsg        = @c_ErrMsg  OUTPUT

     IF @b_Success <> 1
        GOTO RollBackTran
        
	  SELECT @cPickSlipno_Conso = PickHeaderKey 
	  FROM dbo.PICKHEADER WITH (NOLOCK) 
	  WHERE ExternOrderKey = @cLoadkey 
	  AND   OrderKey = ''

      UPDATE PackTask SET 
         TaskBatchNo = @cPickSlipno_Conso 
	   WHERE TaskBatchNo = @cTaskBatchNo
	   
	   IF @@ERROR <> 0
	      GOTO RollBackTran
	      
      --print DN start
      DECLARE CursorPrint CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
      SELECT PH.pickheaderkey 
      FROM dbo.PackTask PT WITH (NOLOCK)
      JOIN dbo.PICKHEADER PH WITH (NOLOCK) ON PH.PickHeaderKey = PT.TaskBatchNo 
      WHERE PT.TaskBatchNo = @cPickSlipno_Conso
      ORDER BY PT.LogicalName
      OPEN CursorPrint        
      FETCH NEXT FROM CursorPrint INTO @cPickSlipno        
      WHILE @@FETCH_STATUS<>-1        
      BEGIN        
                 
				EXEC RDT.rdt_BuiltPrintJob
               @nMobile,
               @cStorerKey,
               'DelNote',
               'r_dw_Delivery_Note62_RDT',
               'r_dw_Delivery_Note62_RDT',
               @cPaperPrinter,
               @cTargetDB,
               @cLangCode,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT,
               @cPickSlipno,
               ''
            IF @nErrNo <> 0
            BEGIN
               CLOSE CursorPrint        
               DEALLOCATE CursorPrint
               GOTO RollBackTran
            END
         FETCH NEXT FROM CursorPrint INTO @cPickSlipno    
      END        
      CLOSE CursorPrint        
      DEALLOCATE CursorPrint
      --print DN end
   END      
   GOTO QUIT         
         
         
        
RollBackTran:            
   ROLLBACK TRAN rdt_593PrintDW02 -- Only rollback change made here            
   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam      
      
       
Quit:            
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started            
      COMMIT TRAN rdt_593PrintDW02          
   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam 

GO