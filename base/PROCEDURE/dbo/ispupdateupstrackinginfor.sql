SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispUpdateUPSTrackingInfor                           */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: To Update the UPS Tracking Number after Carton Label        */
/*          Scanned On UPS Application. UPS insert record thru ODBC     */
/*          Connection to WMS Database                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author      Purposes                                */  
/* 2011-12-28  1.0  SHONG       Created                                 */
/* 2012-03-08  1.1  SHONG       Purging Records with Blank Carton ID    */  
/* 28-Jan-2019 1.2  TLTING_ext  enlarge externorderkey field length     */
/************************************************************************/  
  
CREATE PROC [dbo].[ispUpdateUPSTrackingInfor]  
AS
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @cCartonID   NVARCHAR(20), 
           @nRowID      INT, 
           @cUPSTracking     NVARCHAR(18), 
           @cFreightCharge   NVARCHAR(19), 
           @cInsuranceCharge NVARCHAR(19), 
           @cWeight          NVARCHAR(19),
           @cVoidIndicator   NVARCHAR(1), 
           @cCartonType      NVARCHAR(1), 
           @cWMS_RefKey      NVARCHAR(30), 
           @cWMS_RefType     NVARCHAR(2), 
           @cOrderKey        NVARCHAR(10),
           @cMBOLKey         NVARCHAR(10),
           @cLoadKey         NVARCHAR(10),
           @cExternOrderKey  NVARCHAR(50),   --tlting_ext
           @cBuyerPO         NVARCHAR(20),
           @cZipCode         NVARCHAR(18),
           @cStorerKey       NVARCHAR(15), 
           @cServiceIndicator NVARCHAR(18),
           @cServiceDescr     NVARCHAR(30),
           @cSpecialHandling  NVARCHAR(1),
           @cPickSlipNo       NVARCHAR(10),
           @cUPC              NVARCHAR(30),
           @nCartonNo         INT,
           @bDebug            INT 

-- TraceInfo (Vicky02) - Start
DECLARE    @d_starttime    datetime,
           @d_endtime      datetime,
           @d_step1        datetime,
           @d_step2        datetime,
           @d_step3        datetime,
           @d_step4        datetime,
           @d_step5        datetime,
           @c_col1         NVARCHAR(20),
           @c_col2         NVARCHAR(20),
           @c_col3         NVARCHAR(20),
           @c_col4         NVARCHAR(20),
           @c_col5         NVARCHAR(20),
           @c_TraceName    NVARCHAR(80),
            @d_stepdate     DATETIME      
               ,@n_Step1Ctn   INT      
               ,@n_Step2Ctn   INT      
               ,@n_Step3Ctn   INT      
               ,@n_Step4Ctn   INT      
               ,@n_Step5Ctn   INT              
               
        SET @n_Step1Ctn = 0      
        SET @n_Step2Ctn = 0      
        SET @n_Step3Ctn = 0      
        SET @n_Step4Ctn = 0      
        SET @n_Step5Ctn = 0      
   SET @d_step3 = 0 
   SET @d_step4 = 0  
   SET @d_step5 = 0  

SET @d_starttime = getdate()

SET @c_TraceName = 'ispUpdateUPSTrackingInfor'

   SET @bDebug = 1
   IF EXISTS(SELECT 1 FROM UPSTracking_IN WITH (NOLOCK) WHERE CartonID = '')
   BEGIN
      DELETE UPSTracking_IN 
      WHERE CartonID = ''   	
   END
   
   DECLARE CUR_UPSTrackingUpdate CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT uo.CartonID, 
          MAX(uo.RowID)  
   FROM UPSTracking_IN uo (NOLOCK) 
   WHERE [STATUS] = '0'
   GROUP BY uo.CartonID 

   OPEN CUR_UPSTrackingUpdate 

   FETCH NEXT FROM CUR_UPSTrackingUpdate INTO @cCartonID, @nRowID 
   WHILE @@FETCH_STATUS <> -1
   BEGIN


	   SELECT @cUPSTracking   = ui.UPSTrackingNo, 
	          @cFreightCharge = ui.FreightCharge, 
	          @cInsuranceCharge = ui.InsuranceCharge, 
	          @cWeight          = ui.[Weight],
	          @cVoidIndicator   =  ui.VoidIndicator,
	          @cServiceDescr    = ui.ServiceIndicator 
	   FROM UPSTracking_In ui WITH (NOLOCK)
	   WHERE ui.CartonID = @cCartonID 
	   AND   RowID = @nRowID
   	
	   SELECT TOP 1
	          @cCartonType = uo.CartonType, 
	          @cWMS_RefKey = uo.WMS_RefKey, 
	          @cWMS_RefType = uo.WMS_RefType, 
	          @cServiceIndicator = uo.ServiceIndicator 
	   FROM UPSTracking_Out uo WITH (NOLOCK)
	   WHERE uo.CartonID = @cCartonID
   	
	   IF @cWMS_RefType = 'C' 
	   BEGIN
         SELECT TOP 1 
            @cOrderKey = OrderKey 
         FROM OrderDetail WITH (NOLOCK) 
         WHERE ConsoOrderKey = @cWMS_RefKey 
	   END
	   ELSE IF @cWMS_RefType = 'L'
	   BEGIN
         SELECT TOP 1 
            @cOrderKey = OrderKey 
         FROM LoadplanDetail WITH (NOLOCK) 
         WHERE LoadKey = @cWMS_RefKey
	   END
   	
	   IF ISNULL(RTRIM(@cOrderKey),'') <> ''
	   BEGIN
		   SELECT 
		   @cStorerKey = o.StorerKey, 
         @cLoadKey = o.Loadkey,
		   @cMBOLKey = o.Mbolkey,
		   @cExternOrderKey = o.Externorderkey,
		   @cBuyerPO = o.Buyerpo,
		   @cZipCode = o.C_Zip, 
		   @cSpecialHandling = o.SpecialHandling 
         FROM ORDERS o WITH (NOLOCK)
         WHERE o.OrderKey = @cOrderKey		
	   END   
   		
	   IF @cVoidIndicator <> 'Y'
	   BEGIN
	      IF NOT EXISTS(SELECT 1 FROM CartonShipmentDetail csd WITH (NOLOCK)
	                    WHERE csd.Orderkey = @cOrderKey AND csd.UCCLabelNo = @cCartonID 
	                     )
	      BEGIN
	         INSERT INTO CartonShipmentDetail
	         (
		         Storerkey,
		         Orderkey,
		         Loadkey,
		         Mbolkey,
		         Externorderkey,
		         Buyerpo,
		         UCCLabelNo,
		         CartonWeight,
		         DestinationZipCode,
		         CarrierCode,
		         ClassOfService,
		         TrackingIdType,
		         FormCode,
		         TrackingNumber,
		         GroundBarcodeString,
		         RoutingCode,
		         ASTRA_Barcode,
		         PlannedServiceLevel,
		         ServiceTypeDescription,
		         SpecialHandlingIndicators,
		         DestinationAirportID,
		         ServiceCode,
		         [2dBarcode],
		         CartonCube,
		         FreightCharge,
		         InsCharge
	         )
	         VALUES
	         (
		         @cStorerKey  /* Storerkey	*/,
		         @cOrderKey   /* Orderkey	*/,
		         @cLoadKey    /* Loadkey	*/,
		         @cMBOLKey    /* Mbolkey	*/,
		         @cExternOrderKey  /* Externorderkey	*/,
		         @cBuyerPO    /* Buyerpo	*/,
		         @cCartonID   /* UCCLabelNo	*/,
		         @cWeight     /* CartonWeight	*/,
		         @cZipCode    /* DestinationZipCode	*/,
		         'UPS'        /* CarrierCode	*/,
		         @cServiceIndicator   /* ClassOfService	*/,
		         ''           /* TrackingIdType	*/,
		         ''           /* FormCode	*/,
		         @cUPSTracking /* TrackingNumber	*/,
		         ''            /* GroundBarcodeString	*/,
		         ''            /* RoutingCode	*/,
		         ''            /* ASTRA_Barcode	*/,
		         ''            /* PlannedServiceLevel	*/,
		         @cServiceDescr /* ServiceTypeDescription	*/,
		         @cSpecialHandling /* SpecialHandlingIndicators	*/,
		         ''                /* DestinationAirportID	*/,
		         @cServiceIndicator /* ServiceCode	*/,
		         ''                 /* 2dBarcode	*/,
		         0                  /* CartonCube	*/,
		         @cFreightCharge    /* FreightCharge	*/,
		         @cInsuranceCharge  /* InsCharge	*/
	         ) 

	      END              
	      ELSE
         BEGIN
   	      UPDATE CartonShipmentDetail 
   	         SET TrackingNumber = @cUPSTracking, 
   	             ServiceTypeDescription = @cServiceDescr, 
   	             FreightCharge = @cFreightCharge,
   	             InsCharge = @cInsuranceCharge
   	      WHERE Orderkey = @cOrderKey 
   	      AND   UCCLabelNo = @cCartonID 
         END
      		
		   IF @cCartonType = 'L' 
		   BEGIN
			   SELECT @cPickSlipNo = pd.PickSlipNo, 
			          @cUPC        = pd.UPC,
			          @nCartonNo   = pd.CartonNo
			   FROM PackDetail pd (NOLOCK)
			   WHERE pd.LabelNo = @cCartonID 
			   AND pd.StorerKey = @cStorerKey
   			
			   UPDATE PackDetail
			   SET UPC = @cUPSTracking, ArchiveCop = NULL 
			   WHERE LabelNo = @cCartonID 
			   AND StorerKey = @cStorerKey 
   			
		   END
		   ELSE IF @cCartonType = 'D' 
		   BEGIN
			   SELECT TOP 1
			          @cPickSlipNo = pd.PickSlipNo, 
			          @cUPC        = pd.UPC,
			          @nCartonNo   = pd.CartonNo  
			   FROM PackDetail pd (NOLOCK)
			   WHERE pd.DropID = @cCartonID 
			     AND pd.StorerKey = @cStorerKey 

			   UPDATE PackDetail
			   SET UPC = @cUPSTracking, ArchiveCop = NULL 
			   WHERE DropID = @cCartonID  
			   AND StorerKey = @cStorerKey 
   			
		   END

       IF @bDebug = 1
       BEGIN
         SET @c_Col1 = @cCartonID
         SET @c_Col2 = @cCartonType
         SET @c_Col3 = @cPickSlipNo
         SET @c_Col4 = @nCartonNo
         SET @c_Col5 = @cOrderKey
         SET @d_endtime = GETDATE() 
         INSERT INTO TraceInfo VALUES          
             (RTRIM(@c_TraceName), @d_starttime, @d_endtime          
             ,CONVERT(CHAR(12),@d_endtime - @d_starttime ,114)          
             ,CONVERT(CHAR(12),@d_step1,114)          
             ,CONVERT(CHAR(12),@d_step2,114)          
             ,CONVERT(CHAR(12),@d_step3,114)       
             ,CONVERT(CHAR(12),@d_step4,114)          
             ,CONVERT(CHAR(12),@d_step5,114)        
             ,@c_Col1     -- Col1          
             ,@c_Col2     -- Col2    
             ,@c_Col3     -- Col3    
             ,@c_Col4     -- Col4    
             ,@c_Col5 )

          SELECT @cCartonID '@cCartonID', @cCartonType '@cCartonType', 
          @cPickSlipNo '@cPickSlipNo', @nCartonNo '@nCartonNo'       	
       END
       		   
		   IF NOT EXISTS(SELECT 1 FROM PackInfo pi1 (NOLOCK)
		                 WHERE pi1.PickSlipNo = @cPickSlipNo 
		                 AND   pi1.CartonNo   = @nCartonNo )
		   BEGIN
			   INSERT INTO PACKINFO (PickSlipNo, CartonNo, RefNo, [Weight], [Cube])
			   VALUES (@cPickSlipNo, @nCartonNo, @cCartonID, @cWeight, 0)
		   END
		   ELSE
		   BEGIN
			   UPDATE PACKINFO 
			      SET [Weight] = @cWeight,
			          RefNo = @cUPSTracking
			    WHERE PickSlipNo = @cPickSlipNo 
		       AND   CartonNo   = @nCartonNo  
		   END      
	   END -- IF @cVoidIndicator <> 'Y'
	   ELSE
	   BEGIN
	      IF EXISTS(SELECT 1 FROM CartonShipmentDetail csd WITH (NOLOCK)
	                    WHERE csd.Orderkey = @cOrderKey AND csd.UCCLabelNo = @cCartonID 
	                     )
	      BEGIN
	   	   DELETE FROM CartonShipmentDetail 
	   	   WHERE Orderkey = @cOrderKey 
	   	   AND   UCCLabelNo = @cCartonID 
	      END		
		   IF @cCartonType = 'L' 
		   BEGIN
			   SELECT @cPickSlipNo = pd.PickSlipNo, 
			          @cUPC        = pd.UPC 
			   FROM PackDetail pd (NOLOCK)
			   WHERE pd.LabelNo = @cCartonID 
			   AND pd.StorerKey = @cStorerKey
   			
			   UPDATE PackDetail
			   SET UPC = '', ArchiveCop = NULL 
			   WHERE LabelNo = @cCartonID 
			   AND StorerKey = @cStorerKey 
   			
		   END
		   ELSE IF @cCartonType = 'D' 
		   BEGIN
			   SELECT TOP 1
			          @cPickSlipNo = pd.PickSlipNo, 
			          @cUPC        = pd.UPC,
			          @nCartonNo   = pd.CartonNo  
			   FROM PackDetail pd (NOLOCK)
			   WHERE pd.DropID = @cCartonID 
			     AND pd.StorerKey = @cStorerKey 

			   UPDATE PackDetail
			   SET UPC = '', ArchiveCop = NULL 
			   WHERE DropID = @cCartonID  
			   AND StorerKey = @cStorerKey 
   			
		   END
		   IF EXISTS(SELECT 1 FROM PackInfo pi1 (NOLOCK)
		                 WHERE pi1.PickSlipNo = @cPickSlipNo 
		                 AND   pi1.CartonNo   = @nCartonNo )
		   BEGIN
			   UPDATE PACKINFO 
			      SET RefNo = ''
			    WHERE PickSlipNo = @cPickSlipNo 
		       AND   CartonNo   = @nCartonNo  
		   END  	   
	   END
      
      UPDATE UPSTracking_In
      SET [STATUS] = '9' 
      WHERE CartonID = @cCartonID 
      AND   [Status] = '0'


       IF @bDebug = 1
       BEGIN
         SET @c_Col1 = @cCartonID
         SET @c_Col2 = @cCartonType
         SET @c_Col3 = @cPickSlipNo
         SET @c_Col4 = @nCartonNo
         SET @c_Col5 = 'Completed!'
         SET @d_endtime = GETDATE() 
         INSERT INTO TraceInfo VALUES          
             (RTRIM(@c_TraceName), @d_starttime, @d_endtime          
             ,CONVERT(CHAR(12),@d_endtime - @d_starttime ,114)          
             ,CONVERT(CHAR(12),@d_step1,114)          
             ,CONVERT(CHAR(12),@d_step2,114)          
             ,CONVERT(CHAR(12),@d_step3,114)       
             ,CONVERT(CHAR(12),@d_step4,114)          
             ,CONVERT(CHAR(12),@d_step5,114)        
             ,@c_Col1     -- Col1          
             ,@c_Col2     -- Col2    
             ,@c_Col3     -- Col3    
             ,@c_Col4     -- Col4    
             ,@c_Col5 )
         END   	              
	   FETCH NEXT FROM CUR_UPSTrackingUpdate INTO @cCartonID, @nRowID
   END
   CLOSE CUR_UPSTrackingUpdate 
   DEALLOCATE CUR_UPSTrackingUpdate 

END

GO