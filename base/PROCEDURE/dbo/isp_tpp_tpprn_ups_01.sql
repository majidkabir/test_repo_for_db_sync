SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_TPP_TPPRN_UPS_01                                */
/* Creation Date: 08-NOV-2021                                           */
/* Copyright: LF                                                        */
/* Written by:CSCHONG                                                   */
/*                                                                      */
/* Purpose:WMS-18065 [CN] 511 TACTICAL_UPS_Label_Printing_new_TPPrintSP */
/*                                                                      */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver. Purposes                                   */
/* 08-NOV-2021  CSCHONG 1.0  Devops Scripts combine                     */
/************************************************************************/ 

CREATE PROC [dbo].[isp_TPP_TPPRN_UPS_01] (
   @n_JobNo             BIGINT
   )   
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF     

   DECLARE @n_starttcnt      INT,
           @n_continue       INT,
           @c_SQL            NVARCHAR(4000),
           @b_success        INT,
           @n_err            INT,
           @c_errmsg         NVARCHAR(255)                               

                             
   DECLARE @n_FromCartonNo   INT = 0,
           @n_ToCartonNo     INT = 0,
           @n_CartonNo       INT,
           @c_TrackingNo     NVARCHAR(40),
           @c_PrintData      NVARCHAR(MAX),
           @c_WebSocketURL   NVARCHAR(200) = '',
           @c_RequestString  NVARCHAR(MAX),  
           @c_Status         NVARCHAR(10),
           @c_Message        NVARCHAR(2000),
           @n_RowRef         INT,
           @c_Orderkey       NVARCHAR(10),
           @c_CurrOrderkey   NVARCHAR(10),
           @c_Pickslipno     NVARCHAR(10),  
           @c_Module         NVARCHAR(20), --PACKING, EPACKING
           @c_ReportType     NVARCHAR(10), --UCCLABEL,
           @c_Storerkey      NVARCHAR(15), 
           @c_Printer        NVARCHAR(128), 
           @c_ShipperKey     NVARCHAR(15),    
           @c_KeyFieldName   NVARCHAR(30)='PICKSLIPNO', 
           @c_Parm01         NVARCHAR(30)='',  --e.g. pickslip no
           @c_Parm02         NVARCHAR(30)='',  --e.g. from carton no
           @c_Parm03         NVARCHAR(30)='',  --e.g. to carton no
           @c_Parm04         NVARCHAR(30)='',
           @c_Parm05         NVARCHAR(30)='',
           @c_Parm06         NVARCHAR(30)='',
           @c_Parm07         NVARCHAR(30)='',
           @c_Parm08         NVARCHAR(30)='',
           @c_Parm09         NVARCHAR(500)='',
           @c_Parm10         NVARCHAR(4000)='',
           @c_UDF01          NVARCHAR(200)='',          
           @c_UDF02          NVARCHAR(200)='',         
           @c_UDF03          NVARCHAR(200)='',          
           @c_UDF04          NVARCHAR(500)='',          
           @c_UDF05          NVARCHAR(4000)='',          
           @c_SourceType     NVARCHAR(30) = '', --print from which function    
           @c_Platform       NVARCHAR(30)='',    
           @c_SqlOutput      NVARCHAR(max) = '' ,
           @c_UserName       NVARCHAR(128)= '' ,
           @c_sqlparm        NVARCHAR(max) 
           

   DECLARE @c_Printername   NVARCHAR(128) 
          ,@c_PrinterID     NVARCHAR(10) 
          ,@c_cmdstart      NVARCHAR(100)
          ,@c_RequestID     NVARCHAR(10)
          ,@c_version       NVARCHAR(100)
          ,@c_content       NVARCHAR(MAX)
          ,@c_contentdata   NVARCHAR(500)
          ,@c_TemplathURL   NVARCHAR(500)
          ,@cKeyname        NVARCHAR(30) 
          ,@c_nCounter      NVARCHAR(25)
          ,@c_PrnServerIP   NVARCHAR(50) = ''
          ,@c_PrnServerPort NVARCHAR(10) = ''
          ,@c_jsoncmd       NVARCHAR(MAX)
          ,@c_CloseContent  NVARCHAR(4000) = ''
          ,@c_CustomData    NVARCHAR(4000) = ''


 DECLARE   @c_FromCompanyName NVARCHAR(20),  
           @c_FromCompanyAddress01 NVARCHAR(20),  
           @c_FromCompanyAddress02 NVARCHAR(20),  
           @c_FromCompanyAddress03 NVARCHAR(20),  
           @c_FromCountry NVARCHAR(20),  
           @c_FromZipCode NVARCHAR(20),  
           @c_FromCity NVARCHAR(20),  
           @c_FromPhone NVARCHAR(20),  
           @c_CityTown NVARCHAR(20),  
           @c_ToCompanyName NVARCHAR(20),  
           @c_ToCompanyAddress01 NVARCHAR(20),  
           @c_ToCompanyAddress02 NVARCHAR(20),  
           @c_ToCompanyAddress03 NVARCHAR(20),  
           @c_ToCountry NVARCHAR(20),  
           @c_ToZipCode NVARCHAR(20),  
           @c_ToCity NVARCHAR(20),  
           @c_ToState NVARCHAR(20),  
           @c_ToPhone NVARCHAR(20),  
           @c_FromRI    NVARCHAR(20),  
           @c_Attention NVARCHAR(20),  
           @c_ServiceType NVARCHAR(20),  
           @c_Description NVARCHAR(20),  
           @c_PackType NVARCHAR(20),  
           @c_Shipper NVARCHAR(20),  
           @c_AddDoc NVARCHAR(20),  
           @c_DocOnly NVARCHAR(20),  
           @c_ProcessAsPaper NVARCHAR(20),  
           @c_Invoice NVARCHAR(20),  
           @c_BillTrans NVARCHAR(20),  
           @n_Weight NVARCHAR(20),  
           @c_FromState NVARCHAR(20),  
           @c_labelno  NVARCHAR(20),  
           @c_CInvoice NVARCHAR(20),
           @c_loadkey  NVARCHAR(20),
           @c_lpudf01  NVARCHAR(20),
           @c_WebRequestURL        NVARCHAR(1000),
           @c_FullRequestString    NVARCHAR(MAX),
           @c_Filename             NVARCHAR(200),
           @c_Folder               NVARCHAR(200),
           @c_WebRequestHeaders    NVARCHAR(1000)  
          
          
   
   SELECT @n_starttcnt = @@TRANCOUNT, @n_continue = 1, @b_success = 1, @n_err = 0
   SELECT @c_Message = '', @c_Status = '9' 
   
   --Initialization
   IF @n_continue IN(1,2)
   BEGIN
     SELECT @c_Module=Module, @c_ReportType=ReportType, @c_Storerkey=Storerkey,@c_PrinterID=PrinterID, @c_Printer=Printer, 
               @c_Shipperkey=Shipperkey, @c_KeyFieldName=KeyFieldName,                                       
               @c_Parm01=Parm01, @c_Parm02=Parm02, @c_Parm03=Parm03, @c_Parm04=Parm04, @c_Parm05=Parm05, 
               @c_Parm06=Parm06, @c_Parm07=Parm07, @c_Parm08=Parm08, @c_Parm09=Parm09, @c_Parm10=Parm10,        
               @c_UDF01=UDF01, @c_UDF02=UDF02, @c_UDF03=UDF03, @c_UDF04=UDF04, @c_UDF05=UDF05, @c_SourceType=SourceType,
               @c_Platform=Platform ,@c_UserName = AddWho
        FROM TPPRINTJOB (NOLOCK)
        WHERE JobNo = @n_JobNo                                                 
        
       IF @c_KeyFieldName = 'ORDERKEY'
        BEGIN
          SELECT @c_Orderkey = @c_Parm01
          
           SELECT TOP 1 @c_Pickslipno = PH.PickSlipNo
                      , @c_loadkey = PH.LoadKey
           FROM PACKHEADER PH (NOLOCK)
           JOIN PACKDETAIL PD (NOLOCK) ON PH.PICKSLIPNO=PD.PICKSLIPNO     
           WHERE Orderkey = @c_Parm01 AND PD.LABELNO=@c_Parm02
        END   
        ELSE 
        BEGIN --picklipno
          SELECT  @c_Orderkey = Orderkey
                 , @c_loadkey = LoadKey 
          FROM PACKHEADER (NOLOCK)
          WHERE Pickslipno = @c_Parm01               
          
          SELECT @c_PickslipNo = @c_Parm01
        END              
                                                                                                                        
     --SELECT @c_labelno=caseid  
     --FROM pickdetail (NOLOCK)  
     --WHERE Orderkey=@c_orderkey  
     --AND storerkey=@c_storerkey  

      SELECT @c_labelno=@c_Parm02

     SELECT   @c_ToCompanyName =b_contact1,      
              @c_ToCompanyAddress01 = B_Address1,      
              @c_ToCompanyAddress02 = B_Address2,      
              @c_ToCompanyAddress03 = B_Address3,      
              @c_ToCountry = B_Country,      
              @c_ToZipCode = B_Zip,      
              @c_ToCity = B_City,      
              @c_ToPhone = B_Phone1  
   FROM dbo.orders (NOLOCK)  
   WHERE orderkey=@c_orderkey  
   AND storerkey=@c_storerkey  
  


   SELECT @c_ToState=short   
   FROM codelkup (NOLOCK)  
   WHERE Storerkey=@c_storerkey  
   AND LISTNAME='LFFDXState'  
   AND long=@c_ToCity  


    IF ISNULL(@c_ToState,'') = ''
    BEGIN
       SET @c_ToState = '<blank>'
    END


    SELECT  @c_FromCompanyName = Notes,      
            @c_Attention = Notes2,    
            @c_FromCompanyAddress01 = long,      
            @c_FromCountry = udf02,      
            @c_FromZipCode = UDF01,      
            @c_FromCity = UDf03,      
            @c_FromState = UDF04,      
            @c_FromPhone = udf05,      
            @c_FromRI = code2    
   FROM codelkup (NOLOCK)  
   WHERE Storerkey=@c_storerkey  
   AND LISTNAME='LF2UPS'  
   AND code='100010'  


   SELECT  @c_ServiceType = Notes,  
           @c_Description = Description,  
           @C_PackType= Notes2  
   FROM codelkup (NOLOCK)  
   WHERE Storerkey=@c_storerkey  
   AND LISTNAME='LF2UPS'  
   AND code='100020'  



   SELECT @n_Weight=pi.Weight  
   FROM packinfo pi (NOLOCK) 
   JOIN packdetail pd (NOLOCK)   
   ON pi.CartonNo=pd.CartonNo  AND PI.PickSlipNo = pd.PickSlipNo
   WHERE pd.LabelNo=@c_labelno  
   AND storerkey=@c_storerkey

    SELECT @c_BillTrans=udf01,  
           @c_Shipper=UDF02,  
           @c_AddDoc=UDF03,  
           @c_DocOnly=UDF04,  
           @c_ProcessAsPaper=UDF05,  
           @c_CInvoice =code2  
   FROM codelkup (NOLOCK)  
   WHERE Storerkey=@c_storerkey  
   AND LISTNAME='LF2UPS'  
   AND code='100020'  


     SELECT @c_lpudf01 = LP.userdefine01
     FROM dbo.LoadPlan LP WITH (NOLOCK)
     WHERE loadkey = @c_loadkey


       SET @c_RequestString = '<OpenShipments xmlns="x-schema:OpenShipments.xdr">            
                         <OpenShipment ShipmentOption="" ProcessStatus="">                        
                         <PrinterID>           
                          <LabelID>'+@c_PrinterID+'</LabelID>          
                         </PrinterID>           
                        '  +  '<ShipTo>        
                              <CompanyOrName>'+@c_ToCompanyName+' </CompanyOrName>'      
                              + '<Attention>'+@c_Attention+'</Attention>'      
                              + '<Address1>'+@c_ToCompanyAddress01+'</Address1>'      
                              + '<Address2>'+@c_ToCompanyAddress02+'</Address2>'      
                              + '<Address3>'+@c_ToCompanyAddress03+ '</Address3>'      
                              + '<CountryTerritory>'+@c_ToCountry+ '</CountryTerritory>'      
                              + '<PostalCode> '+@c_ToZipCode+ '</PostalCode>'      
                              + '<CityOrTown> '+@c_ToCity+ '</CityOrTown>'      
                              + '<StateProvinceCounty>'+@c_ToState+'</StateProvinceCounty>'      
                              + '<Telephone>'+@c_ToPhone+'</Telephone>'      
                        +'</ShipTo>            
                     <ShipFrom>'+            
                   '<CompanyOrName>'+@c_FromCompanyName+'</CompanyOrName> '       
                   +'<Attention>'+@c_Attention+'</Attention>'           
                   +'<Address1>'+@c_FromCompanyAddress01+'</Address1>'           
                   +'<Address2>'+@c_FromCompanyAddress02+'</Address2>'           
                   +'<Address3>'+@c_FromCompanyAddress03+'</Address3>'           
                   +'<CountryTerritory>'+@c_FromCountry+'</CountryTerritory>'           
                   +'<PostalCode>'+@c_FromZipCode+'</PostalCode>'          
                   +'<CityOrTown>'+@c_FromCity+'</CityOrTown>'          
                   +'<StateProvinceCounty>'+@c_FromState+'</StateProvinceCounty>'           
                   +'<Telephone>'+@c_ToPhone+'</Telephone>'         
                   +'<ResidentialIndicator>'+@c_FromRI+'</ResidentialIndicator>'         
                   +'</ShipFrom>            
                     <ShipmentInformation>'            
                   +'<ServiceType>'+@c_ServiceType+'</ServiceType>'           
                   +'<PackageType>'+@c_PackType+'</PackageType>'       
                   +'<NumberOfPackages>1</NumberOfPackages>'        
                   +'<ShipmentActualWeight>'+@n_Weight+'</ShipmentActualWeight>'      
                   +'<DescriptionOfGoods>'+@c_Description+'</DescriptionOfGoods>'           
                   +'<BillTransportationTo>'+@c_BillTrans+'</BillTransportationTo>'       
                   +'<Reference1>'+@c_labelno+'</Reference1>'          
                   +'<PrinterID>'           
                   +'   <LabelID>'+@c_PrinterID+'</LabelID>'          
                   +'</PrinterID>'           
                   +'<USI>' + @c_lpudf01 +'</USI>'           
                   +'<ShipperNumber>'+@c_Shipper+'</ShipperNumber>'           
                   +'<AdditionalDocuments>'+@c_AddDoc+'</AdditionalDocuments>'           
                   +'<DocumentOnly>'+@c_DocOnly+'</DocumentOnly>'        
                   +'<ProcessAsPaperless>'+@c_ProcessAsPaper+'</ProcessAsPaperless>'           
                   +'</ShipmentInformation>'            
                   +'<InternationalDocumentation>'            
                   +'<CreateAnInvoice>'+@c_CInvoice+'</CreateAnInvoice>'           
                   +'</InternationalDocumentation>            
                  </OpenShipment>  
     </OpenShipments>'    
   
      SET @c_WebSocketURL = @c_UDF01
         
      CREATE TABLE #TMP_SENDUPSREQUEST 
      (RowID INT IDENTITY(1,1), 
       WebSocketURL NVARCHAR(200), 
       RequestString NVARCHAR(MAX))   
         
         
                IF NOT EXISTS(SELECT 1 FROM dbo.TPPRINTCMDLOG WITH (NOLOCK) WHERE JobNo = @n_JobNo )
                BEGIN
                --Create print job
                 INSERT INTO dbo.TPPRINTCMDLOG
                 (
                     JobNo,
                     CartonNo,
                     PrintCMD ,
                     PrintServerIP,
                     PrintServerPort   
                 )
                 VALUES
                 (   @n_JobNo,         -- JobNo - bigint
                     0,      -- CartonNo - int
                     @c_RequestString,        --printcmd
                     '',          --print server ip  
                     ''         --Print server port
                      
                     ) 
             END
         END


          --Send TS Print request
          --INSERT INTO #TMP_SENDREQUEST (WebSocketURL, RequestString)
          --VALUES (@c_WebSocketURL, ISNULL(@c_RequestString,''))       --CS01


   --update job status and message.
   UPDATE TPPRINTJOB WITH (ROWLOCK)
   SET Status = @c_Status,
       Message = @c_Message
   WHERE JobNo = @n_JobNo
       
SET @c_WebRequestURL            = @c_UDF01
SET @c_FullRequestString        = @c_RequestString
SET @c_Filename                 = @c_Storerkey + '_' + @c_labelno 
SET @c_Folder                   = 'C:\UPSDATA\IMPORT'
SET @c_WebRequestHeaders        = 'FileName:' + @c_Filename + '.xml|Folder:' + @c_Folder
  
SELECT 
    @c_WebRequestURL           [WebRequestURL]
  , 'POST'                     [WebRequestMethod]
  , 'application/xml'          [WebRequestContentType]
  , 'UTF-8'                    [WebRequestEncoding]
  , @c_FullRequestString       [RequestString]
  , 120000                     [WebRequestTimeout]
  , ''                         [NetworkCredentialUserName]
  , ''                         [NetworkCredentialPassword]
  , 0                          [IsSoapRequest]
  , ''                         [RequestHeaderSoapAction]
  , ''                         [HeaderAuthorization]
  , '1'                        [ProxyByPass]
  , @c_WebRequestHeaders       [WebRequestHeaders]
  , 'SELECT 1'                 [PostingSP]
  , 'WSTF'                     [EPServerType]
  , ''                         [WSDTKey]
  , ''                         [SeqNo]
  , ''                         [Datastream]
  , ''                         [ReqBodyEncodeFormat]
  , ''                         [RespBodyDecodeFormat]
  , ''                         [ReqBodyEncodeDataOnly]
  , ''                         [RespBodyDecodeDataOnly]
  , ''                         [FormDatas]
  , ''                         [FileUploadKeyAndSourcePath]
  , ''                         [FileUploadKeyAndContent]
  , ''                         [ClientCertPath]
  , ''                         [ClientCertPassword]

         
   
    
   EXIT_SP:
   
   
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0     
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt 
      BEGIN
         ROLLBACK TRAN
      END
      ELSE 
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt 
         BEGIN
            COMMIT TRAN
         END          
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_TPP_TPPRN_UPS_01"
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE 
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt 
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END

END

GO