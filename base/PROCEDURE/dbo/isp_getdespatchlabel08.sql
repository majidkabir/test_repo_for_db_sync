SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_GetDespatchLabel08                             */      
/* Creation Date: 14-Jun-2010                                           */      
/* Copyright: IDS                                                       */      
/* Written by: SHON                                                     */      
/*                                                                      */      
/* Purpose: Despatch Label For Republic                                 */      
/*                                                                      */      
/*                                                                      */      
/* Called By:                                                           */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author Ver Purposes                                     */      
/* 27-07-2010   Vicky  1.1 Fix double printing & Depot # (Vicky01)      */      
/* 28-07-2010   GTGOH  1.2 SOS#183250 - Add in refno as parameter to be */      
/*                         print in report module  (GOH01)              */    
/* 18-10-2010   James  1.3 Add externorderkey as search criteria        */  
/*                         (james01)                                    */ 
/* 25-10-2010   James  1.4 No printing if pick n pack not match(james02)*/  
/* 29-11-2011   James  1.5 SOS221354 - If countryDestination = 'IE',skip*/ 
/*                         postcode clean up (james03)                  */  
/************************************************************************/      
CREATE PROC [dbo].[isp_GetDespatchLabel08]   
(  
    @cStorerKey          NVARCHAR(15)  
   ,@cOrderKey           NVARCHAR(10)  
   ,@cRefNo              NVARCHAR(20) = ''    --GOH01  
   ,@cExternOrderKey     NVARCHAR(30) = ''    --james01  
)      
AS      
BEGIN  
    SET NOCOUNT ON      
    SET QUOTED_IDENTIFIER OFF      
    SET ANSI_NULLS ON      
    SET CONCAT_NULL_YIELDS_NULL OFF  
      
    DECLARE @nPackCnt    NVARCHAR(1)  
           ,@cCleanPC    NVARCHAR(12)  
           ,@cDepot      NVARCHAR(2) -- (Vicky01)  
           ,@nConUniNo   INT  
           ,@i           TINYINT  
           ,@pi          INT  
           ,@cSQL        NVARCHAR(MAX)      
           ,@nTot_Pick   INT
           ,@nTot_Pack   INT
      
    DECLARE @b_success           INT  
           ,@n_err               INT  
           ,@c_errmsg            NVARCHAR(250)  
           ,@n_continue          INT  
           ,@n_cnt               INT   
           ,@cPostcode           NVARCHAR(18)  
           ,@cCountryDestination NVARCHAR(30)  -- (james03)
           ,@cDepotStyle         NVARCHAR(1)  
           ,@cRound              NVARCHAR(2)  
           ,@cDepotMnemonic      NVARCHAR(4)  
           ,@cSector             NVARCHAR(1)   
           ,@SecStr              NVARCHAR(5)  
           ,@cArea               NVARCHAR(3)  
           ,@nDistrict           NVARCHAR(2)  
           ,@nSector             TINYINT  
           ,@cUnit               NVARCHAR(2)  
      
   --GOH01 Start  
   IF RTRIM(ISNULL(@cOrderKey,'')) = '' AND RTRIM(ISNULL(@cRefNo,'')) <> ''  
   BEGIN      
      SELECT @cOrderKey = PACKHEADER.OrderKey,   
            @cStorerKey = ORDERS.StorerKey   
      FROM PACKDETAIL WITH (NOLOCK)   
      JOIN PACKHEADER WITH (NOLOCK)   
      ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo)  
      JOIN ORDERS WITH (NOLOCK)   
      ON (PACKHEADER.OrderKey = ORDERS.OrderKey)  
      WHERE PACKDETAIL.RefNo = @cRefNo   
   END  
   --GOH01 End  
  
   --james01 Start  
   IF RTRIM(ISNULL(@cOrderKey,'')) = '' AND RTRIM(ISNULL(@cExternOrderKey,'')) <> ''  
   BEGIN      
      SELECT @cOrderKey = OrderKey    
      FROM Orders WITH (NOLOCK)   
      WHERE StorerKey = @cStorerKey  
         AND ExternOrderKey = @cExternOrderKey  
         AND Status <> 'CANC'   
   END  
   --james01 End  

   -- james02 start
   SELECT @nTot_Pick = ISNULL(SUM(QTY), 0) 
   FROM PICKDETAIL PD WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
      AND OrderKey = @cOrderKey
      AND Status >= '5'

   SELECT @nTot_Pack = ISNULL(SUM(QTY), 0) 
   FROM PACKDETAIL PD WITH (NOLOCK)
   JOIN PACKHEADER PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
   WHERE PH.StorerKey = @cStorerKey
      AND PH.OrderKey = @cOrderKey

   IF @nTot_Pick <> @nTot_Pack
   BEGIN
      SELECT TOP 1 ORDERS.UserDefine01, -- (Vicky01)  
      ORDERS.IncoTerm,   
      '' AS [DepotStyle],   
      '' AS [Depot],   
      '' + '' AS [Round],   
      ORDERS.C_contact1,   
      ORDERS.C_Address1,   
      ORDERS.C_Address2,   
      ORDERS.C_Address3,   
      ORDERS.C_Address4,   
      ORDERS.C_Country,   
      ORDERS.C_Zip,   
      ORDERS.Notes2,   
      CODELKUP.Short,   
      '' AS [DepotMnemonic],   
      ORDERS.ExternOrderKey,   
      PACKDETAIL.RefNo,   
      Storer.SUSR4      
      FROM ORDERS (nolock)     
      JOIN Storer WITH (NOLOCK)  
      ON (ORDERS.StorerKey = Storer.StorerKey)   
      JOIN CODELKUP (nolock)   
      ON (CODELKUP.ListName = 'HDNTERMS' AND ORDERS.IncoTerm = CODELKUP.Code)   
      JOIN PACKHEADER WITH (NOLOCK)   
      ON (ORDERS.OrderKey = PACKHEADER.OrderKey)  
      JOIN PACKDETAIL WITH (NOLOCK)   
      ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)  
      WHERE 1 = 2
      
      GOTO Quit
   END
   -- james02 end

   SELECT @cPostcode = o.C_Zip, 
          @cCountryDestination = o.CountryDestination      -- (james03)
   FROM   ORDERS o WITH (NOLOCK)  
   WHERE  o.OrderKey = @cOrderKey  

   -- For label production, where countryDestination = 'IE', and the post code is invalid, set the post code to 'EIRE'
   -- Having done this, the lookups to REPHDNROUTE will get the record where Area = 'EI' and DC = 'RE'
   IF RTRIM(ISNULL(@cCountryDestination,'')) = 'IE' OR SUBSTRING(ISNULL(@cPostcode,''),1,4) = 'BFPO'
   BEGIN
      SET @cArea = 'EI'
      SET @nDistrict = 'RE'

      SELECT TOP 1   
         @cDepot = REPHDNROUTE.Depot,  
         @cDepotStyle = REPHDNROUTE.DepotStyle,   
         @cRound      = REPHDNROUTE.Round,  
         @cSector     = REPHDNROUTE.Sector  
      FROM   dbo.REPHDNRoute REPHDNROUTE   
      WHERE  Area = @cArea  
      AND    DC = @nDistrict  

      GOTO CONTINUE_HERE
   END

    SET @cCleanPC = ''      
    SET @pi = 1      
    WHILE @pi<=LEN(@cPostcode)  
    BEGIN  
        SET @i = 48 -- NVARCHAR(48) = 0      
        WHILE @i<123 -- NVARCHAR(122) = z  
        BEGIN  
            IF (@i>47 AND @i<58)              OR (@i>64 AND @i<91)  
                -- OR (@i > 96 AND @i < 123)    no need to check uppercase as not case-sensitive      
                IF SUBSTRING(@cPostcode ,@pi ,1)=CHAR(@i)  
                    SET @cCleanPC = @cCleanPC+SUBSTRING(@cPostcode ,@pi ,1)  
              
           SET @i = @i+1  
        END      
        SET @pi = @pi+1  
    END      
      

      
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

         IF ISNUMERIC(SUBSTRING(@cCleanPC ,3 ,1)) = 1
            SET @nSector = SUBSTRING(@cCleanPC ,3 ,1)  
         ELSE
            GOTO Quit
      END  
      ELSE   
      IF @SecStr='A###A'  
      BEGIN  
         SET @nDistrict = SUBSTRING(@cCleanPC ,2 ,2)      

         IF ISNUMERIC(SUBSTRING(@cCleanPC ,4 ,1)) = 1
            SET @nSector = SUBSTRING(@cCleanPC ,4 ,1)  
         ELSE
            GOTO Quit
      END  
      ELSE   
      IF @SecStr='A#A#A'  
      BEGIN  
         SET @nDistrict = SUBSTRING(@cCleanPC ,2 ,2)      

         IF ISNUMERIC(SUBSTRING(@cCleanPC ,4 ,1)) = 1
            SET @nSector = SUBSTRING(@cCleanPC ,4 ,1)  
         ELSE
            GOTO Quit
      END  
      ELSE   
      IF @SecStr='AA##A'  
      BEGIN  
         SET @nDistrict = SUBSTRING(@cCleanPC ,3 ,1)      

         IF ISNUMERIC(SUBSTRING(@cCleanPC ,4 ,1)) = 1
            SET @nSector = SUBSTRING(@cCleanPC ,4 ,1)  
         ELSE
            GOTO Quit
      END  
      ELSE   
      IF @SecStr='AA###'  
      BEGIN  
         SET @nDistrict = SUBSTRING(@cCleanPC ,3 ,2)      

         IF ISNUMERIC(SUBSTRING(@cCleanPC ,5 ,1)) = 1
            SET @nSector = SUBSTRING(@cCleanPC ,5 ,1)  
         ELSE
            GOTO Quit
      END  
      ELSE   
      IF @SecStr='AA#A#'  
      BEGIN  
         SET @nDistrict = SUBSTRING(@cCleanPC ,3 ,2)      

         IF ISNUMERIC(SUBSTRING(@cCleanPC ,5 ,1)) = 1
            SET @nSector = SUBSTRING(@cCleanPC ,5 ,1)  
         ELSE
            GOTO Quit
      END  
      ELSE   
      IF @SecStr='AAA#A'  
      BEGIN  
         SET @nDistrict = ''      

         IF ISNUMERIC(SUBSTRING(@cCleanPC ,4 ,1)) = 1
            SET @nSector = SUBSTRING(@cCleanPC ,4 ,1)  
         ELSE
            GOTO Quit
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
         @cDepot = REPHDNROUTE.Depot,  
         @cDepotStyle = REPHDNROUTE.DepotStyle,   
         @cRound      = REPHDNROUTE.Round,  
         @cSector     = REPHDNROUTE.Sector  
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

    CONTINUE_HERE:   -- (james03)      
    SELECT @cDepotMnemonic = REPHDNDepot.DepotMnemonic  
    FROM   REPHDNDepot WITH (NOLOCK)  
    WHERE  REPHDNDepot.DepotNumber = @cDepot  
      
   SELECT TOP 1 ORDERS.UserDefine01, -- (Vicky01)  
       ORDERS.IncoTerm,   
     @cDepotStyle AS [DepotStyle],   
     @cDepot AS [Depot],   
     @cRound + @cSector AS [Round],   
     ORDERS.C_contact1,   
     ORDERS.C_Address1,   
     ORDERS.C_Address2,   
     ORDERS.C_Address3,   
     ORDERS.C_Address4,   
      ORDERS.C_Country,   
      ORDERS.C_Zip,   
     ORDERS.Notes2,   
     CODELKUP.Short,   
     @cDepotMnemonic AS [DepotMnemonic],   
     ORDERS.ExternOrderKey,   
     PACKDETAIL.RefNo,   
     Storer.SUSR4      
   FROM ORDERS (nolock)     
   JOIN Storer WITH (NOLOCK)  
   ON (ORDERS.StorerKey = Storer.StorerKey)   
   JOIN CODELKUP (nolock)   
   ON (CODELKUP.ListName = 'HDNTERMS' AND ORDERS.IncoTerm = CODELKUP.Code)   
   JOIN PACKHEADER WITH (NOLOCK)   
   ON (ORDERS.OrderKey = PACKHEADER.OrderKey)  
   JOIN PACKDETAIL WITH (NOLOCK)   
   ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)  
   WHERE (ORDERS.Storerkey = @cStorerKey )     
   AND (ORDERS.OrderKey = @cOrderKey)   

Quit:

END -- procedure     

GO