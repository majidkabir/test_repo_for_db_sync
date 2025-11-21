SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdtScan2TruckExtInfo                               */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Decode Label No Scanned                                     */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 03-09-2012  1.0  ChewKP      SOS272994. Created                      */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdtScan2TruckExtInfo]  
   @c_MBOLKey        NVARCHAR(10),  
   @c_DropID         NVARCHAR(20),  
   @c_StorerKey      NVARCHAR(15),
   @c_ToggleDropID   NVARCHAR(1),
   @c_oFieled01      NVARCHAR(20) OUTPUT,  
   @c_BatchComplete  NVARCHAR(1)  OUTPUT  -- 1 = Completed , 0 = InComplete
   
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_DropIDCount INT
         , @n_DropIDTotal INT
   
   SET @n_DropIDCount = 0
   SET @n_DropIDTotal = 0
   SET @c_BatchComplete = '0'
   
   IF @c_ToggleDropID = '1'
   BEGIN
      SELECT @n_DropIDTotal = COUNT( DISTINCT PD.DropID)
      FROM dbo.MBOLDetail MD WITH (NOLOCK)
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON MD.OrderKey = PH.OrderKey
      JOIN dbo.PackDetail PD WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
      WHERE MD.MbolKey = @c_MBOLKey
   END
   ELSE IF @c_ToggleDropID = '2'
   BEGIN
      SELECT @n_DropIDTotal = COUNT( DISTINCT PD.DropID)
      FROM dbo.MBOLDetail MD WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON MD.OrderKey = PD.OrderKey
      WHERE MD.MbolKey = @c_MBOLKey
   END
   
   
      
   SELECT @n_DropIDCount = COUNT( DISTINCT URNNo) 
   FROM RDT.RDTScanToTruck WITH (NOLOCK) 
   WHERE MbolKey = @c_MBOLKey
   
   
   SET @c_oFieled01 = CAST(@n_DropIDCount AS NVARCHAR(5)) + '/' + CAST(@n_DropIDTotal AS NVARCHAR(5))
   
   
   IF @n_DropIDTotal = @n_DropIDCount
   BEGIN
      SET @c_BatchComplete = '1'
   END
   
   
   
       
QUIT:  
END -- End Procedure  

GO