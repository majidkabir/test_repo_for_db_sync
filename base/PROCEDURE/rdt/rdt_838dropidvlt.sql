SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838DropIDVLT                                    */
/*                                                                      */
/*                                                                      */
/* Date         Author   Purposes                                       */
/* 17/05/2024   PPA374   Inserts DROPID in the DropID table             */
/************************************************************************/

CREATE   PROC [RDT].[rdt_838DropIDVLT] (
   @nMobile         INT,            
   @nFunc           INT,            
   @cLangCode       NVARCHAR( 3),   
   @nStep           INT,            
   @nInputKey       INT,            
   @cFacility       NVARCHAR( 5),   
   @cStorerKey      NVARCHAR( 15),  
   @cPickSlipNo     NVARCHAR( 10),  
   @cFromDropID     NVARCHAR( 20),  
   @nCartonNo       INT,            
   @cLabelNo        NVARCHAR( 20),  
   @cSKU            NVARCHAR( 20),  
   @nQTY            INT,            
   @cUCCNo          NVARCHAR( 20),  
   @cCartonType     NVARCHAR( 10),  
   @cCube           NVARCHAR( 10),  
   @cWeight         NVARCHAR( 10),  
   @cRefNo          NVARCHAR( 20),  
   @cSerialNo       NVARCHAR( 30),  
   @nSerialQTY      INT,            
   @cOption         NVARCHAR( 1),   
   @cPackDtlRefNo   NVARCHAR( 20),  
   @cPackDtlRefNo2  NVARCHAR( 20),  
   @cPackDtlUPC     NVARCHAR( 30),  
   @cPackDtlDropID  NVARCHAR( 20),  
   @cPackData1      NVARCHAR( 30),  
   @cPackData2      NVARCHAR( 30),  
   @cPackData3      NVARCHAR( 30),  
   @nErrNo          INT            OUTPUT,  
   @cErrMsg         NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
   @LOADKEY nvarchar(20),
   @PICKSLIP nvarchar(20)

   --Finding load key AND pickslip number
   SELECT TOP 1 @LOADKEY = LoadKey FROM ORDERS (NOLOCK) WHERE orderkey = (SELECT TOP 1 OrderKey FROM PICKDETAIL (NOLOCK) WHERE DropID = @cFromDropID)
   SELECT TOP 1 @PICKSLIP = PickHeaderKey FROM PICKHEADER (NOLOCK) WHERE orderkey = (SELECT TOP 1 OrderKey FROM PICKDETAIL (NOLOCK) WHERE DropID = @cFromDropID)
   
   IF @nFunc = 838
   BEGIN
      --If operator is NOT printing the label for DROPID AND drop id record does NOT exist in the DropID table
      IF @nStep = 5 -- Print Label
         AND @cOption = 2 -- no
         AND NOT EXISTS (SELECT 1 FROM dropid WHERE dropid = @cPackDtlDropID)
      BEGIN
         INSERT INTO Dropid(Dropid,Droploc,AdditionalLoc,DropIDType,LabelPrinted,ManifestPrinted,Status,AddDate,AddWho,EditDate,EditWho,TrafficCop,ArchiveCop,Loadkey,PickSlipNo,UDF01,UDF02,UDF03,UDF04,UDF05)
         VALUES(@cPackDtlDropID,'','',0,'N',0,5,GETDATE(),SUSER_NAME(),GETDATE(),SUSER_NAME(),null,null,@LOADKEY,@PICKSLIP,'','','','','')
      END

      --If operator is printing the label for DROPID AND drop id record does NOT exist in the DropID table
      ELSE IF @nStep = 5 --Print Label
     AND @cOption = 1 -- Yes
     AND NOT EXISTS (SELECT 1 FROM dropid WHERE dropid = @cPackDtlDropID)
      BEGIN
         INSERT INTO Dropid(Dropid,Droploc,AdditionalLoc,DropIDType,LabelPrinted,ManifestPrinted,Status,AddDate,AddWho,EditDate,EditWho,TrafficCop,ArchiveCop,Loadkey,PickSlipNo,UDF01,UDF02,UDF03,UDF04,UDF05)
         VALUES(@cPackDtlDropID,'','',0,'Y',0,5,GETDATE(),SUSER_NAME(),GETDATE(),SUSER_NAME(),null,null,@LOADKEY,@PICKSLIP,'','','','','')
      END

      --If operator is printing the label for DROPID AND drop id record already exist in the DropID table
      ELSE IF @nStep = 5 -- Print Label
     AND @cOption = 1 -- Yes
     AND EXISTS (SELECT 1 FROM dropid WHERE dropid = @cPackDtlDropID AND LabelPrinted = 'N')
      BEGIN
         UPDATE dropid
         SET LabelPrinted = 'Y'
         WHERE dropid = @cPackDtlDropID
      END

     --Inserting DropID into the DropID table at SKU QTY step. Required in scenarios when label will NOT be printed.
      IF @nStep = 3 -- SKU QTY
     AND NOT EXISTS (SELECT 1 FROM dropid WHERE dropid = @cPackDtlDropID)
      BEGIN
         INSERT INTO Dropid(Dropid,Droploc,AdditionalLoc,DropIDType,LabelPrinted,ManifestPrinted,Status,AddDate,AddWho,EditDate,EditWho,TrafficCop,ArchiveCop,Loadkey,PickSlipNo,UDF01,UDF02,UDF03,UDF04,UDF05)
         VALUES(@cPackDtlDropID,'','',0,'N',0,5,GETDATE(),SUSER_NAME(),GETDATE(),SUSER_NAME(),null,null,@LOADKEY,@PICKSLIP,'','','','','')
      END
   END
END

GO