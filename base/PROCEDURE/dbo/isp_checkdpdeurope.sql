SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: isp_CheckDPDEurope                                  */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Check valid data before allowing to print DPD label for     */  
/*          Europe                                                      */
/* Called from: rdt_EcommDispatch_Confirm                               */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author Purposes                                     */  
/* 28Oct2010   1.1  GTGOH  SOS#193695 - Change 'EI' to 'IE' (GOH01)     */   
/************************************************************************/  
CREATE PROC [dbo].[isp_CheckDPDEurope]   
   @c_StorerKey   NVARCHAR(15),  
   @c_OrderKey    NVARCHAR(10),   
   @b_success  int = 1 OUTPUT,  
   @n_err      int = 0 OUTPUT,  
   @c_errmsg   NVARCHAR(225) = '' OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF      
  
   
DECLARE  @c_accno    NVARCHAR(6),   
         @c_idsname  NVARCHAR(45),   
         @c_add1     NVARCHAR(45),  
         @c_add2     NVARCHAR(45),  
         @c_add3     NVARCHAR(45),  
         @c_add4     NVARCHAR(45),  
         @c_contact1 NVARCHAR(30),  
         @c_phone1   NVARCHAR(18),  
         @c_c_name    NVARCHAR(45),   
         @c_c_add1   NVARCHAR(45),  
         @c_c_add2   NVARCHAR(45),  
         @c_c_add3   NVARCHAR(45),  
         @c_c_add4   NVARCHAR(45),  
         @c_c_contact1  NVARCHAR(30),  
         @c_c_phone1 NVARCHAR(18),  
         @c_trackno  NVARCHAR(15),  
         @c_orgtrackno  NVARCHAR(15),  
         @c_srvdesc  NVARCHAR(30),  
         @c_maxweight   NVARCHAR(5),  
         @c_height   NVARCHAR(5),  
         @c_weight   NVARCHAR(5),  
         @c_length   NVARCHAR(5),  
         @c_proddesc NVARCHAR(30),       
         @c_susr1    NVARCHAR(20),       
         @c_susr2    NVARCHAR(20),   
         @c_susr3    NVARCHAR(20),   
         @c_susr4    NVARCHAR(20),   
         @c_incoterm NVARCHAR(10),   
         @c_m_vat    NVARCHAR(18),    --to store parcel number       
         @c_cdigit   NVARCHAR(1),  
         @f_value    float,   
         @c_c_country   NVARCHAR(30),   
         @c_c_zip    NVARCHAR(18),   
         @c_ISOcode  NVARCHAR(3),   
         @c_AllowExpress   NVARCHAR(1),  
         @c_AllowClassic   NVARCHAR(1),  
         @c_EUCnt    NVARCHAR(1),  
         @c_Depot    NVARCHAR(9),   
         @c_OSort    NVARCHAR(4),  
         @c_DSort    NVARCHAR(4),   
         @c_IATAcode NVARCHAR(2),   
         @c_externorderkey NVARCHAR(30),   
         @c_srvcode  NVARCHAR(3),  
         @c_depottype   NVARCHAR(1),        
         @c_barcode  NVARCHAR(28),  
         @c_checkflag   varchar(1)  --GOH02  
           
    DECLARE @cCleanPC    NVARCHAR(12)  
           ,@cDepot      NVARCHAR(2)  
           ,@nConUniNo   INT  
           ,@i           TINYINT  
           ,@pi          INT  
           ,@cSQL        NVARCHAR(MAX)      
  
  
      SELECT @c_accno = RTRIM(ISNULL(STORER.VAT,'')),   
         @c_idsname  = RTRIM(ISNULL(STORER.Company,'')),   
         @c_add1     = RTRIM(ISNULL(STORER.Address1,'')),  
         @c_add2     = RTRIM(ISNULL(STORER.Address2,'')),  
         @c_add3     = RTRIM(ISNULL(STORER.Address3,'')),  
         @c_add4     = RTRIM(ISNULL(STORER.Address4,'')),  
         @c_contact1 = RTRIM(ISNULL(STORER.Contact1,'')),  
         @c_phone1   = RTRIM(ISNULL(STORER.Phone1,'')),   
         @c_susr1    = RTRIM(ISNULL(STORER.SUSR1,'')),   
         @c_susr2    = RTRIM(ISNULL(STORER.SUSR2,'')),   
         @c_susr3    = RTRIM(ISNULL(STORER.SUSR3,'')),   
         @c_susr4    = RTRIM(ISNULL(STORER.SUSR4,''))   
      FROM STORER WITH (NOLOCK) WHERE STORER.StorerKey = 'IDS'  
        
      IF @c_accno = ''  
      BEGIN   
         SET @n_err = 60006  
         SET @c_errmsg = 'Invalid Account Number. isp_CheckDPDEurope'  
         GOTO QUIT  
      END   
        
      SELECT @c_m_vat = RTRIM(ISNULL(ORDERS.M_Vat,'')),  
         @c_c_name  = RTRIM(ISNULL(ORDERS.C_Company,'')),   
         @c_c_add1     = RTRIM(ISNULL(ORDERS.C_Address1,'')),  
         @c_c_add2     = RTRIM(ISNULL(ORDERS.C_Address2,'')),  
         @c_c_add3     = RTRIM(ISNULL(ORDERS.C_Address3,'')),  
         @c_c_add4     = RTRIM(ISNULL(ORDERS.C_Address4,'')),  
         @c_c_contact1 = RTRIM(ISNULL(ORDERS.C_Contact1,'')),  
         @c_c_phone1   = RTRIM(ISNULL(ORDERS.C_Phone1,'')),  
         @c_c_country  = RTRIM(ISNULL(ORDERS.CountryDestination,'')),  
         @c_c_zip      = RTRIM(ISNULL(ORDERS.C_Zip,'')),  
         @c_incoterm   = RTRIM(ISNULL(ORDERS.IncoTerm,'')),   
         @c_externorderkey = RTRIM(ISNULL(ORDERS.ExternOrderKey,''))  
      FROM ORDERS WITH (NOLOCK)  
      WHERE ORDERS.OrderKey = @c_OrderKey   
      AND ORDERS.StorerKey = @c_StorerKey   
        
      IF @c_m_vat = ''   
      BEGIN  
         EXECUTE nspg_GetKey  
            'PARCELNO',   
            6,  
            @c_m_vat    OUTPUT,  
            @b_success  OUTPUT,  
            @n_err      OUTPUT,  
            @c_errmsg   OUTPUT  
              
         IF @b_success <> 1  
         BEGIN   
            SET @n_err = 60001  
            SET @c_errmsg = 'FAIL To Generate Parcel Number. isp_CheckDPDEurope'  
            GOTO QUIT  
         END   
           
         UPDATE ORDERS WITH (ROWLOCK)      
         SET M_Vat = @c_m_vat   
         WHERE ORDERS.OrderKey = @c_OrderKey   
         AND ORDERS.StorerKey = @c_StorerKey   
           
      END  

        --GOH02 Start  
      IF EXISTS (SELECT 1 FROM Codelkup WITH (NOLOCK)   
      WHERE Listname = 'IETERMS' AND Code = @c_incoterm)   
      BEGIN  
         SET @c_checkflag = 'N'  
      END  
      ELSE  
      BEGIN   
         SET @c_checkflag = 'Y'  
      END  
      --GOH02 End  
        
      SET @c_orgtrackno = CAST(@c_susr1 AS NVARCHAR(4)) + CAST(@c_susr2 AS NVARCHAR(4)) + RTRIM(@c_m_vat)  
        
      EXEC isp_CheckDigitsISO7064   
         @c_orgtrackno,   
         @b_success OUTPUT,   
         @c_cdigit  OUTPUT  
        
      IF @b_success <> 1  
      BEGIN   
         SET @n_err = 60002  
         SET @c_errmsg = 'FAIL To Check Digit for Parcel Number:' + @c_orgtrackno + ' isp_CheckDPDEurope'  
         GOTO QUIT  
      END   
  
      SET @c_trackno = RTRIM(@c_orgtrackno) + @c_cdigit  
  
      SELECT @c_srvdesc = REPDPDSRV.DPDLabelSrvDescr,  
         @c_maxweight = REPDPDSRV.MaxweightperParcel,  
         @c_proddesc  = REPDPDSRV.DPDProdDescr,   
         @c_srvcode = REPDPDSRV.GeoSrvCode    
      FROM REPDPDSRV WITH(NOLOCK)  
      WHERE REPDPDSRV.GeoSrvCode = SUBSTRING(@c_incoterm,1,3)  
         
      SELECT @c_EUCnt = 'E' WHERE @c_proddesc like '%Express%'  
      SELECT @c_EUCnt = 'C' WHERE @c_proddesc like '%Classic%'  
      IF @c_EUCnt <> 'E' AND @c_EUCnt <> 'C' AND @c_checkflag = 'Y'  
      BEGIN   
         SET @n_err = 60004  
         SET @c_errmsg = 'Invalid Service Type. isp_CheckDPDEurope'  
         GOTO QUIT  
      END   
              
      SELECT @c_ISOcode = (CASE @c_c_country WHEN 'UK' THEN '826'    
                         WHEN 'GB' THEN '826'         
--    GOH01              WHEN 'EI' THEN '372'     
                         WHEN 'IE' THEN '372'     
                         ELSE REPDPDCNT.ISOcode END),   
         @c_IATAcode = REPDPDCNT.IATAcode,   
         @c_AllowExpress = REPDPDCNT.AllowExpress,   
         @c_AllowClassic = REPDPDCNT.AllowClassic   
      FROM REPDPDCNT WITH(NOLOCK)   
      WHERE REPDPDCNT.IATAcode = @c_c_country  
  
--GOH01    
      SELECT @c_ISOcode = (CASE @c_c_country WHEN 'UK' THEN '826'      
                         WHEN 'GB' THEN '826'           
                         WHEN 'IE' THEN '372' ELSE @c_ISOcode END)  
                           
      IF RTRIM(ISNULL(@c_ISOcode,'')) = ''  AND @c_checkflag = 'Y'  
      BEGIN   
         SET @n_err = 60006  
         SET @c_errmsg = 'Invalid IATAcode in REPDPDCNT: ' + @c_c_country + ' isp_CheckDPDEurope'  
         GOTO QUIT  
      END  

      IF @c_c_country <> 'IE'   --GOH01  
      BEGIN  
  
         SELECT @c_Depot = CASE WHEN @c_EUCnt = 'E' THEN REPDPDZIP.ExpTrafficDepot  
                           ELSE REPDPDZIP.ClassicTrafficDepot END,   
            @c_OSort  =  CASE WHEN @c_EUCnt = 'E' THEN REPDPDZIP.ExpTrafficOSort  
                         ELSE REPDPDZIP.ClassicTrafficOSort END,   
            @c_DSort  = CASE WHEN @c_EUCnt = 'E' THEN REPDPDZIP.ExpTrafficDSort  
                        ELSE REPDPDZIP.ClassicTrafficDSort END  
         FROM REPDPDZIP WITH(NOLOCK)  
         WHERE  (REPDPDZIP.IATAcode = @c_IATAcode  
         AND REPDPDZIP.ZipcodeFrom <= @c_c_zip  
         AND REPDPDZIP.ZipcodeTo >= @c_c_zip)  
         OR (REPDPDZIP.IATAcode = @c_IATAcode  
         AND REPDPDZIP.ZipcodeFrom = '0'  
         AND REPDPDZIP.ZipcodeTo = 'Z')  
           
         IF RTRIM(ISNULL(@c_Depot,'')) = ''  AND @c_checkflag = 'Y'  
         BEGIN   
            SET @n_err = 60006  
            SET @c_errmsg = 'Invalid Zip Code in REPDPDZIP: ' + @c_c_zip + ' ' + @c_IATAcode + ' isp_CheckDPDEurope'  
            GOTO QUIT  
         END  
           
         --Duplicate from despatch label  
          SET @cCleanPC = ''      
          SET @pi = 1      
          WHILE @pi<=LEN(@c_c_zip)  
          BEGIN  
              SET @i = 48 -- NVARCHAR(48) = 0      
              WHILE @i<123 -- NVARCHAR(122) = z  
              BEGIN  
                  IF (@i>47 AND @i<58)  
                  OR (@i>64 AND @i<91)  
                      -- OR (@i > 96 AND @i < 123)    no need to check uppercase as not case-sensitive      
                      IF SUBSTRING(@c_c_zip ,@pi ,1)=CHAR(@i)  
                          SET @cCleanPC = @cCleanPC+SUBSTRING(@c_c_zip ,@pi ,1)  
                    
                 SET @i = @i+1  
              END      
              SET @pi = @pi+1  
          END      
            
          DECLARE @SecStr     NVARCHAR(5)  
                 ,@cArea      NVARCHAR(3)  
                 ,@nDistrict  NVARCHAR(2)  
                 ,@nSector    TINYINT  
                 ,@cUnit      NVARCHAR(2)  
            
          IF ISNUMERIC(SUBSTRING(@cCleanPC ,2 ,1))=1  
          BEGIN  
              -- A#      
              SET @cArea = LEFT(@cCleanPC ,1)      
              IF ISNUMERIC(SUBSTRING(@cCleanPC ,3 ,1))=1  
              BEGIN  
                  -- A##      
                  IF ISNUMERIC(SUBSTRING(@cCleanPC ,4 ,1))=1  
                      SET @SecStr = 'A###A'  
                  ELSE  
                      SET @SecStr = 'A##AA'  
              END  
              ELSE  
              BEGIN  
                  -- A#A      
                  SET @SecStr = 'A#A#A'  
              END  
          END  
          ELSE  
          BEGIN  
              -- AA      
              IF ISNUMERIC(SUBSTRING(@cCleanPC ,3 ,1))=1  
              BEGIN  
                  -- AA#      
                  SET @cArea = LEFT(@cCleanPC ,2)      
                  IF ISNUMERIC(SUBSTRING(@cCleanPC ,4 ,1))=1  
               BEGIN  
                      -- AA##      
               IF ISNUMERIC(SUBSTRING(@cCleanPC ,5 ,1))=1  
                SET @SecStr = 'AA###'  
                      ELSE  
                          SET @SecStr = 'AA##A'  
                  END  
                  ELSE  
                  BEGIN  
                      -- AA#A      
                      SET @SecStr = 'AA#A#'  
                  END  
              END  
              ELSE  
              BEGIN  
                  -- AAA      
                  SET @cArea = LEFT(@cCleanPC ,3)      
                  SET @SecStr = 'AAA#A'  
              END  
          END      
            
            
          IF @SecStr='A##AA'  
          BEGIN  
              SET @nDistrict = SUBSTRING(@cCleanPC ,2 ,1)      
              SET @nSector = SUBSTRING(@cCleanPC ,3 ,1)  
          END  
          ELSE   
          IF @SecStr='A###A'  
          BEGIN  
              SET @nDistrict = SUBSTRING(@cCleanPC ,2 ,2)      
              SET @nSector = SUBSTRING(@cCleanPC ,4 ,1)  
          END  
          ELSE   
          IF @SecStr='A#A#A'  
          BEGIN  
              SET @nDistrict = SUBSTRING(@cCleanPC ,2 ,2)      
              SET @nSector = SUBSTRING(@cCleanPC ,4 ,1)  
          END  
          ELSE   
          IF @SecStr='AA##A'  
          BEGIN  
              SET @nDistrict = SUBSTRING(@cCleanPC ,3 ,1)      
              SET @nSector = SUBSTRING(@cCleanPC ,4 ,1)  
          END  
          ELSE   
          IF @SecStr='AA###'  
          BEGIN  
              SET @nDistrict = SUBSTRING(@cCleanPC ,3 ,2)      
              SET @nSector = SUBSTRING(@cCleanPC ,5 ,1)  
          END  
          ELSE   
          IF @SecStr='AA#A#'  
          BEGIN  
              SET @nDistrict = SUBSTRING(@cCleanPC ,3 ,2)      
              SET @nSector = SUBSTRING(@cCleanPC ,5 ,1)  
          END  
          ELSE   
          IF @SecStr='AAA#A'  
          BEGIN  
              SET @nDistrict = ''      
              SET @nSector = SUBSTRING(@cCleanPC ,4 ,1)  
          END      
            
          IF LEN(@cCleanPC)<8  
              SET @cUnit = RIGHT(@cCleanPC ,2)  
          ELSE   
          IF @SecStr='A##AA'  
              SET @cUnit = SUBSTRING(@cCleanPC ,4 ,2)  
          ELSE   
          IF RIGHT(@SecStr ,1)='A'  
              SET @cUnit = SUBSTRING(@cCleanPC ,5 ,2)  
          ELSE   
          IF RIGHT(@SecStr ,1)='#'  
              SET @cUnit = SUBSTRING(@cCleanPC ,6 ,2)      
            
          SELECT TOP 1   
             @cDepot = REPHDNROUTE.Depot  
          FROM   dbo.REPHDNRoute REPHDNROUTE   
          WHERE  Area = @cArea  
          AND    DC = @nDistrict  
          AND    DepartmentSection = CAST(@nSector AS NVARCHAR(1))  
          AND    UnitLow<= @cUnit  
          AND    UnitHigh>= @cUnit    
            
          IF @@ROWCOUNT=0  
          BEGIN  
              SELECT @cDepot = Depot  
              FROM   dbo.REPHDNRoute  
              WHERE  Area = @cArea  
              AND    DC = @nDistrict  
              AND    DepartmentSection = CAST(@nSector AS NVARCHAR(1))  
                
              IF @@ROWCOUNT=0  
              BEGIN  
                  SELECT @cDepot = Depot  
                  FROM   dbo.REPHDNRoute  
                  WHERE  Area = 'ZY'  
                  AND    DC = '99'  
                  AND    DepartmentSection = '9'  
                  AND    UnitLow = 'AA'  
                    
                  IF @@ROWCOUNT=0  
                      SET @cDepot = '00' -- one man product;  87 for two man product  
              END  
          END  
         
          SELECT @c_depottype = REPHDNDepot.Type  
          FROM   REPHDNDepot WITH (NOLOCK)  
          WHERE  REPHDNDepot.DepotNumber = @cDepot  
      END --   @c_c_country <> 'IE' 
  
      IF RTRIM(ISNULL(@c_barcode,'')) = ''   
      BEGIN   
--GOH01  IF @c_IATAcode = 'EI'     
         IF @c_IATAcode = 'IE'  
         BEGIN   
            IF EXISTS (SELECT 1 WHERE @c_add1 like '%Dublin%' OR @c_add2 like '%Dublin%'   
               OR @c_add3 like '%Dublin%' OR @c_add4 like '%Dublin%')   
            BEGIN   
               SET @c_barcode = '0000001' + @c_orgtrackno + @c_srvcode + @c_ISOcode  
            END  
            ELSE  
            BEGIN   
               SET @c_barcode = '0000002' + @c_orgtrackno + @c_srvcode + @c_ISOcode  
            END  
         END  
         ELSE  
         BEGIN  
            SET @c_barcode = ISNULL(CONVERT(Nchar(7), RIGHT(REPLICATE('0',7) + RTRIM(LTRIM( replace(@c_c_zip,' ',''))),7)),REPLICATE('0',7))    
                             + @c_orgtrackno + @c_srvcode + @c_ISOcode  
         END                            
                                     
         EXEC isp_CheckDigitsISO7064   
            @c_barcode,   
            @b_success OUTPUT,   
            @c_cdigit  OUTPUT  
           
         IF @b_success <> 1  
         BEGIN   
            SET @n_err = 60003  
            SET @c_errmsg = 'FAIL To Check Digit for Bar Code: ' + @c_barcode + ' isp_CheckDPDEurope'  
            GOTO QUIT  
         END   
  
         SET @c_barcode = RTRIM(@c_barcode) + @c_cdigit  
           
         UPDATE PackInfo WITH (ROWLOCK)      
         SET RefNo = @c_barcode   
         FROM PackHeader WITH (NOLOCK)  
         WHERE PackHeader.OrderKey = @c_OrderKey    
         AND PackHeader.StorerKey = @c_StorerKey  
         AND PackInfo.PickSlipNo = PackHeader.PickSlipNo  
      END  
              
   QUIT:   
END

GO