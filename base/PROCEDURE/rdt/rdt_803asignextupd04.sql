SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/******************************************************************************/    
/* Store procedure: rdt_803AsignExtUpd04                                      */    
/* Copyright      : LFLogistics                                               */    
/*                                                                            */    
/* Date       Rev  Author   Purposes                                          */    
/* 06-04-2023 1.0  yeekung   WMS-23257 Created                                */
/******************************************************************************/    
CREATE   PROC [RDT].[rdt_803AsignExtUpd04] (    
   @nMobile     INT,               
   @nFunc       INT,               
   @cLangCode   NVARCHAR( 3),      
   @nStep       INT,               
   @nInputKey   INT,               
   @cFacility   NVARCHAR( 5) ,     
   @cStorerKey  NVARCHAR( 10),     
   @cStation    NVARCHAR( 10),      
   @cMethod     NVARCHAR( 15),     
   @cCurrentSP  NVARCHAR( 60),     
   @tVar        VariableTable READONLY,     
   @nErrNo      INT           OUTPUT,      
   @cErrMsg     NVARCHAR(250) OUTPUT     
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @cBatchkey NVARCHAR(20),    
           @cDevicePos nvarchar(MAX),    
           @cType NVARCHAR(20),    
           @cDeviceStatus NVARCHAR(1),
           @c_DeviceModel NVARCHAR(20),
           @bSuccess       INT
  
   DECLARE @cLightPos nvarchar(20)    
    
    
   -- Parameter mapping    
   SELECT @cBatchkey = Value FROM @tVar WHERE Variable = '@cBatchKey'    
    
   SELECT @cType = Value FROM @tVar WHERE Variable = '@cType'  
      
   SET @cDeviceStatus=rdt.RDTGetConfig( @nFunc, 'PTLErrLUP', @cStorerKey)  


   SELECT top 1 @c_DeviceModel = devicemodel
   FROM deviceprofile WITH (NOLOCK)    
   WHERE deviceid = @cStation    
    
   IF @nStep='2'    
   BEGIN    
    
      IF NOT EXISTS( SELECT 1    
               FROM rdt.rdtPTLPieceLog L WITH (NOLOCK)         
                  JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = L.OrderKey)        
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)        
               WHERE L.Station = @cStation        
                  AND PD.Status <='5'     
                  AND PD.CaseID = ''        
                  AND PD.QTY > 0  )    
    
      BEGIN    
  
         /*Michael */
		   

  
         /* SET @cDevicePos=@cDevicePos+'XX'  */

         SET @cDeviceStatus=rdt.RDTGetConfig( @nFunc, 'PTLLightLUP', @cStorerKey)  
         
			SET @cDevicePos=@cStation +'YY'

         EXEC PTL.isp_PTL_LightUpLoc
         @n_Func           = @nFunc
         ,@n_PTLKey         = 0
         ,@c_DisplayValue   = ''
         ,@b_Success        = @bSuccess    OUTPUT
         ,@n_Err            = @nErrNo      OUTPUT
         ,@c_ErrMsg         = @cErrMsg     OUTPUT
         ,@c_DeviceID       = @cStation
         ,@c_DevicePos      = @cDevicePos
         ,@c_DeviceIP       = ''
         ,@c_LModMode       = @cDeviceStatus
         ,@c_DeviceModel    = @c_DeviceModel
    
         IF @nErrNo<>0    
            GOTO QUIt    
      END    
    
           
    
   END   
   ELSE IF @nStep='3'    
   BEGIN    
    
      IF EXISTS( SELECT 1    
               FROM rdt.rdtPTLPieceLog L WITH (NOLOCK)         
                  JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = L.OrderKey)        
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)        
               WHERE L.Station = @cStation        
                  AND PD.Status <='5'     
                  AND PD.CaseID = ''        
                  AND PD.QTY > 0  )    
    
      BEGIN    
             
         DECLARE cursor_lightpos CURSOR FOR     
         SELECT L.position    
         FROM rdt.rdtPTLPieceLog L WITH (NOLOCK)  
            JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = L.OrderKey)      
            JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)        
         WHERE L.Station = @cStation        
            AND PD.Status <='5'     
            AND PD.CaseID = ''        
            AND PD.QTY > 0       
         GROUP BY  L.position     
    
         OPEN cursor_lightpos      
         FETCH NEXT FROM cursor_lightpos INTO @cLightPos      
    
         WHILE @@FETCH_STATUS = 0      
         BEGIN      
            SET @cDevicePos = CASE WHEN ISNULL(@cDevicePos,'')='' THEN @cLightPos else @cDevicePos+','+@cLightPos END    
    
            FETCH NEXT FROM cursor_lightpos INTO @cLightPos      
         END    
    
         CLOSE cursor_lightpos      
         DEALLOCATE cursor_lightpos     
    

      END  
      ELSE
      BEGIN
         SET @cDeviceStatus=rdt.RDTGetConfig( @nFunc, 'PTLLightLUP', @cStorerKey)  
         
			SET @cDevicePos=@cStation +'YY'

      END

      EXEC PTL.isp_PTL_LightUpLoc
         @n_Func           = @nFunc
         ,@n_PTLKey         = 0
         ,@c_DisplayValue   = ''
         ,@b_Success        = @bSuccess    OUTPUT
         ,@n_Err            = @nErrNo      OUTPUT
         ,@c_ErrMsg         = @cErrMsg     OUTPUT
         ,@c_DeviceID       = @cStation
         ,@c_DevicePos      = @cDevicePos
         ,@c_DeviceIP       = ''
         ,@c_LModMode       = @cDeviceStatus
         ,@c_DeviceModel    = @c_DeviceModel 
    
      IF @nErrNo<>0    
         GOTO QUIt    
    
   END      
    
Quit:    
    
END 

GO