SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/******************************************************************************/              
/* Store Procedure: isp_return_ticket_zara                                    */              
/* Creation Date: 27-JUL-2015                                                 */              
/* Copyright: IDS                                                             */              
/* Written by: CSCHONG                                                        */              
/*                                                                            */              
/* Purpose: SOS#348032 - Zara's Return Report improvement                     */  
/*                                                                            */              
/*                                                                            */              
/* Called By:  r_dw_return_ticket_zara                                       */              
/*                                                                            */              
/* PVCS Version: 1.0                                                          */              
/*                                                                            */              
/* Version: 1.0                                                               */              
/*                                                                            */              
/* Data Modifications:                                                        */              
/*                                                                            */              
/* Updates:                                                                   */              
/* Date         Author    Ver.  Purposes                                      */            
/* 12-Nov-2015  James     1.1   Add ExternLineNo to temp table to fix         */
/*                              orderdetail has 2 same sku (james01)          */
/* 28-Jan-2019  TLTING_ext 1.2  enlarge externorderkey field length      */
/******************************************************************************/     
  
CREATE PROC [dbo].[isp_return_ticket_zara]             
       (@c_Storerkey NVARCHAR(15),
        @c_Orderkey  NVARCHAR(10))              
AS            
BEGIN            
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @c_usrdef03        NVARCHAR(18)
          ,@c_FieldDesc01     NVARCHAR(100)
          ,@c_FieldDesc02     NVARCHAR(100)
          ,@c_FieldDesc03     NVARCHAR(100)
          ,@c_FieldDesc04     NVARCHAR(100)
          ,@c_FieldDesc05     NVARCHAR(100)
          ,@c_FieldDesc06     NVARCHAR(100)
          ,@c_FieldDesc07     NVARCHAR(100)
          ,@c_FieldDesc08     NVARCHAR(100)
          ,@c_FieldDesc09     NVARCHAR(100)
          ,@c_FieldDesc10     NVARCHAR(100)
          ,@c_FieldDesc11     NVARCHAR(100)
          ,@c_FieldDesc12     NVARCHAR(100)
          ,@c_FieldDesc13     NVARCHAR(100)
          ,@c_notes nvarchar(250)
          ,@c_udf01 nvarchar(100) 



          SET @c_FieldDesc01    = ''
          SET @c_FieldDesc02    = ''
          SET @c_FieldDesc03     = ''
          SET @c_FieldDesc04     = ''
          SET @c_FieldDesc05     = ''
          SET @c_FieldDesc06     = ''
          SET @c_FieldDesc07     = ''
          SET @c_FieldDesc08     = ''
          SET @c_FieldDesc09     = ''
          SET @c_FieldDesc10     = ''
          SET @c_FieldDesc11     = ''
          SET @c_FieldDesc12     = ''
          SET @c_FieldDesc13     = ''

 
CREATE TABLE #ReportFieldCode 
         ( fieldcode       NVARCHAR(45) NULL
         , fieldvalue      NVARCHAR(100) NULL 
         , udf02           NVARCHAR(20) NULL)


CREATE TABLE #ReturnZARA 
         ( ExTernOrderKey       NVARCHAR(50) NULL  --tlting_ext
         , m_address3           NVARCHAR(45) NULL 
         , m_address4           NVARCHAR(45) NULL
         , b_address1           NVARCHAR(30) NULL
         , b_address2           NVARCHAR(45) NULL 
         , b_address3           NVARCHAR(45) NULL
         , b_address4           NVARCHAR(45) NULL
         , b_zip                NVARCHAR(18) NULL
         , b_city               NVARCHAR(45) NULL 
         , b_state              NVARCHAR(45) NULL
         , userdefine02         NVARCHAR(20) NULL
         , c_vat                NVARCHAR(18) NULL
         , buyerpo              NVARCHAR(20) NULL 
         , notes                NVARCHAR(4000) NULL
         , sku                  NVARCHAR(17) NULL
         , altsku               NVARCHAR(20) NULL
         , userdefine03         NVARCHAR(18) NULL
         , originalqty          INT NULL 
         , extendedprice        NVARCHAR(10) NULL
         , editdate             NVARCHAR(30) NULL
         , notes1               NVARCHAR(4000) NULL
         , address1             NVARCHAR(92) NULL
         , address3             NVARCHAR(65) NULL
         , orders_userdefine05  NVARCHAR(20) NULL
         , orders_deliveryplace NVARCHAR(30) NULL
         , orders_pmtterm       NVARCHAR(10) NULL
         , orders_door          NVARCHAR(10) NULL
         , orders_ordergroup    NVARCHAR(20) NULL
         , Storerkey            NVARCHAR(15) NULL
         , orderkey             NVARCHAR(10) NULL
        --, Fieldcode1           NVARCHAR(20) NULL
         , Fielddesc1           NVARCHAR(200) NULL
        -- , Fieldcode2           NVARCHAR(20) NULL
         , Fielddesc2           NVARCHAR(200) NULL
        -- , Fieldcode3           NVARCHAR(20) NULL
         , Fielddesc3           NVARCHAR(200) NULL
         --, Fieldcode4           NVARCHAR(20) NULL
         , Fielddesc4           NVARCHAR(200) NULL
        -- , Fieldcode5           NVARCHAR(20) NULL
         , Fielddesc5           NVARCHAR(200) NULL
         --, Fieldcode6           NVARCHAR(20) NULL
         , Fielddesc6           NVARCHAR(200) NULL
         --, Fieldcode7           NVARCHAR(20) NULL
         , Fielddesc7           NVARCHAR(200) NULL
        -- , Fieldcode8           NVARCHAR(20) NULL
         , Fielddesc8           NVARCHAR(200) NULL
        --,Fieldcode9           NVARCHAR(20) NULL
         , Fielddesc9           NVARCHAR(200) NULL
         --, Fieldcode10          NVARCHAR(20) NULL
         , Fielddesc10          NVARCHAR(200) NULL
         --, Fieldcode11          NVARCHAR(20) NULL
         , Fielddesc11          NVARCHAR(200) NULL
         --, Fieldcode12          NVARCHAR(20) NULL
         , Fielddesc12          NVARCHAR(200) NULL
         --, Fieldcode13          NVARCHAR(20) NULL
         , Fielddesc13          NVARCHAR(200) NULL 
         , CountryDestination   NVARCHAR(30) NULL 
         , URL                  NVARCHAR(100) NULL 
         , ExternLineNo         NVARCHAR(10) NULL          
)
  
 INSERT INTO #ReturnZARA 
         ( ExTernOrderKey, m_address3           
         , m_address4    , b_address1          
         , b_address2    ,  b_address3           
         , b_address4    , b_zip                
         , b_city        , b_state             
         , userdefine02  , c_vat                
         , buyerpo       , notes               
         , sku           , altsku              
         , userdefine03  , originalqty           
         , extendedprice , editdate             
         , notes1        , address1            
         , address3      , orders_userdefine05  
         , orders_deliveryplace , orders_pmtterm      
         , orders_door          , orders_ordergroup,storerkey,orderkey,CountryDestination,URL, ExternLineNo)   

SELECT  DISTINCT 
	ORDERS.ExTernOrderKey, 
	ORDERS.M_Address3,
	ORDERS.M_Address4,
	ORDERS.B_Address1,
	ORDERS.B_Address2,
	ORDERS.B_Address3,
	ORDERS.B_Address4,
	ORDERS.B_ZIP,
    	ORDERS.B_CITY,
	ORDERS.B_STATE,
	ORDERS.USERDEFINE02,
--ORDERS.C_VAT,
	CASE WHEN (CHARINDEX(',', ORDERS.C_VAT) > 0 OR ISNULL(ORDERS.C_VAT,'') = '') THEN ORDERS.C_VAT ELSE CONVERT(NVARCHAR(10), CAST(CAST(ORDERS.C_VAT AS DECIMAL(10, 2)) AS MONEY), 1) END AS C_VAT,
	ORDERS.BuyerPO,
	ORDERS.Notes, 
	SUBSTRING(ORDERDETAIL.SKU,  1, 1) + '/' + 
	SUBSTRING(ORDERDETAIL.SKU,  2, 4) + '/' +
	SUBSTRING(ORDERDETAIL.SKU,  6, 3) + '/' +
	SUBSTRING(ORDERDETAIL.SKU,  9, 3) + '/' +
	SUBSTRING(ORDERDETAIL.SKU, 12, 2) AS SKU, 
	ORDERDETAIL.ALTSKU,
	ORDERDETAIL.USERDEFINE03,
	ORDERDETAIL.OriginalQty, 
	CONVERT(NVARCHAR(10), CAST(CAST(ORDERDETAIL.Extendedprice AS DECIMAL(10, 2)) AS MONEY), 1) AS EXTENDEDPRICE, 
	CONVERT(NVARCHAR( 30), PACKHEADER.EDITDATE, 102) AS EDITDATE,
	SKU.NOTES1,  
	CASE WHEN M_Address3 = '' AND M_Address4 = '' THEN '' 
             WHEN M_Address3 <> '' AND M_Address4 = '' THEN M_Address3 
             WHEN M_Address3 = '' AND M_Address4 <> '' THEN M_Address4 
			WHEN M_Address3 <> '' AND M_Address4 <> '' THEN M_Address3 + ', ' + M_Address4 
			ELSE '' END AS ADDRESS1, 
	CASE WHEN B_ZIP = '' AND B_CITY = '' THEN '' 
             WHEN B_ZIP <> '' AND B_CITY = '' THEN B_ZIP 
             WHEN B_ZIP = '' AND B_CITY <> '' THEN B_CITY 
			WHEN B_ZIP <> '' AND B_CITY <> '' THEN B_ZIP + ', ' + B_CITY 
			ELSE '' END AS ADDRESS3, 
	ORDERS.USERDEFINE05, 
	ORDERS.DeliveryPlace, 
     ORDERS.PmtTerm, 
     ORDERS.Door, 
     ORDERS.OrderGroup,
    @c_Storerkey,
    @c_Orderkey,
   --ORDERS.USERDEFINE10,
  --  C1.fieldcode,
--    C.notes
  --C1.fieldvalue
  ORDERS.CountryDestination,
  CASE WHEN (ORDERS.Door='TMALL' AND ORDERS.CountryDestination='CN') THEN 'z     a     r     a     .     t     m     a     l     l     .     c     o     m' 
       WHEN (ORDERS.Door<>'TMALL' AND ORDERS.CountryDestination='CN') THEN 'w     w     w     .     z     a     r     a     .     c     n' 
       ELSE 'w     w     w     .     z     a     r     a     .     c     o     m' END As URL,
       ExternLineNo
  FROM ORDERS WITH (NOLOCK) 
  JOIN ORDERDETAIL WITH (NOLOCK) 
       ON ORDERS.ORDERKEY = ORDERDETAIL.ORDERKEY 
       AND ORDERS.STORERKEY = ORDERDETAIL.STORERKEY 
  JOIN PACKHEADER WITH (NOLOCK) ON ORDERS.ORDERKEY = PACKHEADER.ORDERKEY
  JOIN SKU WITH (NOLOCK) ON ORDERDETAIL.SKU = SKU.SKU AND ORDERDETAIL.STORERKEY = SKU.STORERKEY
  --JOIN #ReportFieldCode C1 WITH (NOLOCK) ON C1.UDF02=ORDERS.USERDEFINE10 --AND UDF01='3'
  WHERE ORDERS.STORERKEY = @c_Storerkey
  AND   ORDERS.ORDERKEY = @c_Orderkey

SELECT @c_usrdef03 = CountryDestination
FROM ORDERS WITH (NOLOCK)
WHERE ORDERKEY = @c_Orderkey

INSERT INTO #ReportFieldCode (fieldcode,fieldvalue,udf02)
SELECT udf01,notes,udf02 
FROM codelkup (nolock)
WHERE listname = 'ZARARTNLNG' 
AND udf02=@c_usrdef03 



DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
 SELECT udf01,notes 
from codelkup (nolock)
where listname = 'ZARARTNLNG' 
and udf02=@c_usrdef03
order by udf01

  OPEN CUR_RowNoLoop 
  FETCH NEXT FROM CUR_RowNoLoop INTO @c_udf01,@c_notes   
       
   WHILE @@FETCH_STATUS <> -1          
   BEGIN         

if @c_udf01= '1' 
BEGIN
  SET @c_FieldDesc01 = @c_notes
END
else if @c_udf01= '2'
BEGIN
  SET @c_FieldDesc02 = @c_notes
END
else if @c_udf01= '3'
BEGIN
  SET @c_FieldDesc03 = @c_notes
END
else if @c_udf01 = '4'
BEGIN
  SET @c_FieldDesc04 = @c_notes
END
else if @c_udf01 = '5'
BEGIN
  SET @c_FieldDesc05 = @c_notes
END
else if @c_udf01 = '6'
BEGIN
  SET @c_FieldDesc06 = @c_notes
END
else if @c_udf01 = '7'
BEGIN
  SET @c_FieldDesc07 = @c_notes
END
else if @c_udf01 = '8'
BEGIN
  SET @c_FieldDesc08 = @c_notes
END
else if @c_udf01 = '9'
BEGIN
  SET @c_FieldDesc09 = @c_notes
END
else if @c_udf01 = '10'
BEGIN
  SET @c_FieldDesc10 = @c_notes
END
else if @c_udf01 = '11'
BEGIN
  SET @c_FieldDesc11 = @c_notes
END
else if @c_udf01 = '12'
BEGIN
  SET @c_FieldDesc12= @c_notes
END
else if @c_udf01 = '13'
BEGIN
  SET @c_FieldDesc13 = @c_notes
END


FETCH NEXT FROM CUR_RowNoLoop INTO @c_udf01,@c_notes      
  END -- While           
  CLOSE CUR_RowNoLoop          
  DEALLOCATE CUR_RowNoLoop 


    UPDATE #ReturnZARA
    SET  Fielddesc1 = @c_FieldDesc01
        ,Fielddesc2 = @c_FieldDesc02
        ,Fielddesc3 = @c_FieldDesc03
        ,Fielddesc4 = @c_FieldDesc04
        ,Fielddesc5 = @c_FieldDesc05
        ,Fielddesc6 = @c_FieldDesc06
        ,Fielddesc7 = @c_FieldDesc07
        ,Fielddesc8 = @c_FieldDesc08
        ,Fielddesc9 = @c_FieldDesc09
        ,Fielddesc10 = @c_FieldDesc10
        ,Fielddesc11 = @c_FieldDesc11
        ,Fielddesc12 = @c_FieldDesc12
        ,Fielddesc13 = @c_FieldDesc13
    WHERE Storerkey=@c_Storerkey
    AND Orderkey=@c_Orderkey
               
END


SELECT 
           ExTernOrderKey       
         , m_address3           
         , m_address4           
         , b_address1           
         , b_address2           
         , b_address3           
         , b_address4           
         , b_zip                
         , b_city               
         , b_state              
         , userdefine02         
         , c_vat                
         , buyerpo              
         , notes                
         , sku                  
         , altsku               
         , userdefine03         
         , originalqty          
         , extendedprice        
         , editdate             
         , notes1               
         , address1             
         , address3             
         , orders_userdefine05  
         , orders_deliveryplace 
         , orders_pmtterm       
         , orders_door          
         , orders_ordergroup    
         , Storerkey            
         , orderkey             
         , Fielddesc1           
         , Fielddesc2           
         , Fielddesc3           
         , Fielddesc4           
         , Fielddesc5           
         , Fielddesc6           
         , Fielddesc7           
         , Fielddesc8           
         , Fielddesc9           
         , Fielddesc10          
         , Fielddesc11          
         , Fielddesc12          
         , Fielddesc13          
         , CountryDestination   
         , URL                  
FROM #ReturnZARA


GO