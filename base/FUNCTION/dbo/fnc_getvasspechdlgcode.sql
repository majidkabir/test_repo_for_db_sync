SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE FUNCTION [dbo].[fnc_GetVasSpecHdlgCode]
(
	@cStorerKey NVARCHAR(15)
   ,@cFacility NVARCHAR(5)
   ,@cType NVARCHAR(10)
   ,@cVendor NVARCHAR(45)
   ,@cBrand NVARCHAR(30)
   ,@cDivision NVARCHAR(10)
   ,@cItemClass NVARCHAR(10)
   ,@cSKUGroup NVARCHAR(10)
   ,@cCustomerID NVARCHAR(20)
   ,@cConsigneeKey NVARCHAR(15)
   ,@cMarkForKey NVARCHAR(15)
   ,@cLottable01 NVARCHAR(18)
   ,@cLottable02 NVARCHAR(18)
   ,@cLottable03 NVARCHAR(18)
)
RETURNS NVARCHAR(10)
AS
BEGIN

 DECLARE @nMatchPoint INT  
        ,@cVasVendor NVARCHAR(45)  
        ,@cVasBrand NVARCHAR(30)  
        ,@cVasDivision NVARCHAR(10)  
        ,@cVasItemClass NVARCHAR(10)  
        ,@cVasSKUGroup NVARCHAR(10)  
        ,@cVasCustomerID NVARCHAR(20)  
        ,@cVasConsigneeKey NVARCHAR(15)  
        ,@cVasMarkForKey NVARCHAR(15)  
        ,@cVasLottable01 NVARCHAR(18)  
        ,@cVasLottable02 NVARCHAR(18)  
        ,@cVasLottable03 NVARCHAR(18)  
        ,@cReturnHdlCode NVARCHAR(10)  
        ,@cVasOrdSpecHdlgCode NVARCHAR(10)  
        ,@cVasKey             NVARCHAR(10)   
        ,@nTotMatchPoint      INT  
  
 DECLARE @t_MatchHdlCode TABLE (VasKey NVARCHAR(10), OrdSpecHdlgCode NVARCHAR(10), MatchPoint INT)  
     
 SET @nMatchPoint = 0   
 SET @cReturnHdlCode = ''  
   
 DECLARE CUR_VAS CURSOR LOCAL FAST_FORWARD READ_ONLY   
 FOR  
     SELECT v.Vendor 
           ,v.Brand  
           ,v.Division  
           ,v.ItemClass  
           ,v.SkuGroup  
           ,v.CustomerID  
           ,v.ConsigneeKey  
           ,v.MarkForKey  
           ,v.Lottable01  
           ,v.Lottable02  
           ,v.Lottable03  
           ,v.OrdSpecHdlgCode  
           ,v.VASKey             
     FROM   VAS v WITH (NOLOCK)  
     WHERE  v.StorerKey = @cStorerKey  
     AND    v.Facility = @cFacility  
     AND    v.[Type] = @cType  
     AND    V.CustomerID = @cCustomerID 
     UNION 
     SELECT v.Vendor  
           ,v.Brand  
           ,v.Division  
           ,v.ItemClass  
           ,v.SkuGroup  
           ,v.CustomerID  
           ,v.ConsigneeKey  
           ,v.MarkForKey  
           ,v.Lottable01  
           ,v.Lottable02  
           ,v.Lottable03  
           ,v.OrdSpecHdlgCode  
           ,v.VASKey             
     FROM   VAS v WITH (NOLOCK)  
     WHERE  v.StorerKey = @cStorerKey  
     AND    v.Facility = @cFacility  
     AND    v.[Type] = @cType  
     AND    V.CustomerID = '' 
   
 OPEN CUR_VAS  
   
 FETCH NEXT FROM CUR_VAS INTO @cVasVendor, @cVasBrand, @cVasDivision,   
    @cVasItemClass, @cVasSKUGroup,    @cVasCustomerID, @cVasConsigneeKey,  
    @cVasMarkForKey, @cVasLottable01, @cVasLottable02, @cVasLottable03,  
    @cVasOrdSpecHdlgCode,  @cVASKey   
   
 WHILE @@FETCH_STATUS <> -1  
 BEGIN  
    SET @nTotMatchPoint = CASE WHEN ISNULL(RTRIM(@cVasBrand),'') <> '' THEN 1 ELSE 0 END +  
                            CASE WHEN ISNULL(RTRIM(@cVasDivision),'') <> '' THEN 1 ELSE 0 END +  
                            CASE WHEN ISNULL(RTRIM(@cVasItemClass),'') <> '' THEN 1 ELSE 0 END +  
                            CASE WHEN ISNULL(RTRIM(@cVasSKUGroup),'') <> '' THEN 1 ELSE 0 END +  
                            CASE WHEN ISNULL(RTRIM(@cVasCustomerID),'') <> '' THEN 1 ELSE 0 END +  
                            CASE WHEN ISNULL(RTRIM(@cVasConsigneeKey),'') <> '' THEN 1 ELSE 0 END +  
                            CASE WHEN ISNULL(RTRIM(@cVasMarkForKey),'') <> '' THEN 1 ELSE 0 END +  
                            CASE WHEN ISNULL(RTRIM(@cVasLottable01),'') <> '' THEN 1 ELSE 0 END +  
                            CASE WHEN ISNULL(RTRIM(@cVasLottable02),'') <> '' THEN 1 ELSE 0 END +  
                            CASE WHEN ISNULL(RTRIM(@cVasLottable03),'') <> '' THEN 1 ELSE 0 END   
                            --CASE WHEN ISNULL(RTRIM(@cVasVendor),'') <> '' THEN 1 ELSE 0 END +   
    
                              
        
      SET @nMatchPoint = 0  
     
--  IF LEFT(@cVasVendor,2) <> '<>' AND  ISNULL(RTRIM(@cVendor),'') = ISNULL(RTRIM(@cVasVendor),'') AND ISNULL(RTRIM(@cVasVendor),'') <> ''  
--     SET @nMatchPoint = @nMatchPoint + 1  
--      ELSE IF LEFT(@cVendor,2) = '<>' AND  ISNULL(RTRIM(@cVendor),'') <> ISNULL(RTRIM(@cVasVendor),'') AND ISNULL(RTRIM(@cVasVendor),'') <> ''  
--         SET @nMatchPoint = @nMatchPoint + 1  
           
     IF LEFT(@cVasBrand,2) <> '<>' AND  
        ISNULL(RTRIM(@cBrand),'') = ISNULL(RTRIM(@cVasBrand),'') AND 
        ISNULL(RTRIM(@cVasBrand),'') <> ''
     BEGIN
  	     SET @nMatchPoint = @nMatchPoint + 1 
  	     --PRINT '@cVasBrand'
     END    
     ELSE
     IF LEFT(@cVasBrand,2) = '<>' AND    
         ISNULL(RTRIM(@cBrand),'') <> SubString(ISNULL(RTRIM(@cVasBrand),''), 3, LEN(@cVasBrand) - 2) AND  
         ISNULL(RTRIM(@cVasBrand),'') <> ''  
     BEGIN
  	     SET @nMatchPoint = @nMatchPoint + 1 
  	     --PRINT '<>@cVasBrand'
     END  
                
     IF LEFT(@cVasDivision,2) <> '<>' AND  
        ISNULL(RTRIM(@cDivision),'') = ISNULL(RTRIM(@cVasDivision),'') AND 
        ISNULL(RTRIM(@cVasDivision),'') <> ''  
     BEGIN
  	     SET @nMatchPoint = @nMatchPoint + 1 
  	     --PRINT '<>@cVasDivision'
     END  
     ELSE   
     IF LEFT(@cVasDivision,2) = '<>' AND    
         ISNULL(RTRIM(@cDivision),'') <> SubString(ISNULL(RTRIM(@cVasDivision),''), 3, LEN(@cVasDivision) - 2)  AND   
         ISNULL(RTRIM(@cVasDivision),'') <> ''  
     BEGIN
  	     SET @nMatchPoint = @nMatchPoint + 1 
  	     --PRINT '@cVasDivision'
     END  
     
              
     IF LEFT(@cVasItemClass,2) <> '<>' AND    
        ISNULL(RTRIM(@cItemClass),'') = ISNULL(RTRIM(@cVasItemClass),'') AND           
        ISNULL(RTRIM(@cVasItemClass),'') <> ''  
     BEGIN
  	     SET @nMatchPoint = @nMatchPoint + 1 
  	     --PRINT '@cVasItemClass'
     END   
     ELSE IF LEFT(@cVasItemClass,2) = '<>' AND  
           ISNULL(RTRIM(@cItemClass),'') <> SubString(ISNULL(RTRIM(@cVasItemClass),''), 3, LEN(@cVasItemClass) - 2) AND      
           ISNULL(RTRIM(@cVasItemClass),'') <> ''  
     BEGIN
  	     SET @nMatchPoint = @nMatchPoint + 1 
  	     --PRINT '<>@cVasItemClass'
     END     
     
                                
     IF LEFT(@cVasSkuGroup,2) <> '<>' AND  
        ISNULL(RTRIM(@cSkuGroup),'') = ISNULL(RTRIM(@cVasSkuGroup),'') AND 
        ISNULL(RTRIM(@cVasSkuGroup),'')  <> ''
     BEGIN       
        SET @nMatchPoint = @nMatchPoint + 1
     END        
     ELSE   
     IF LEFT(@cVasSkuGroup,2) = '<>' AND    
        ISNULL(RTRIM(@cSkuGroup),'') <>  SubString(ISNULL(RTRIM(@cVasSkuGroup),''), 3, LEN(@cVasSkuGroup) - 2) AND   
        ISNULL(RTRIM(@cVasSkuGroup),'')  <> ''
     BEGIN     
         SET @nMatchPoint = @nMatchPoint + 1  
     END
     
     IF LEFT(@cVasCustomerID,2) <> '<>' AND  
        ISNULL(RTRIM(@cCustomerID),'') = ISNULL(RTRIM(@cVasCustomerID),'') AND 
        ISNULL(RTRIM(@cVasCustomerID),'') <> ''  
     BEGIN
  	     SET @nMatchPoint = @nMatchPoint + 1 
  	     --PRINT '<>@cVasCustomerID'
     END     
     ELSE   
     IF LEFT(@cVasCustomerID,2) = '<>' AND    
        ISNULL(RTRIM(@cCustomerID),'') <>  SubString(ISNULL(RTRIM(@cVasCustomerID),''), 3, LEN(@cVasCustomerID) - 2) AND   
        ISNULL(RTRIM(@cVasCustomerID),'') <> ''  
     BEGIN
  	     SET @nMatchPoint = @nMatchPoint + 1 
  	     --PRINT '@cVasCustomerID'
     END
        
     IF LEFT(@cVasMarkForKey ,2)<>'<>'  
        AND ISNULL(RTRIM(@cMarkForKey) ,'')=ISNULL(RTRIM(@cVasMarkForKey) ,'')  
        AND ISNULL(RTRIM(@cVasMarkForKey) ,'')<>''  
     BEGIN
  	     SET @nMatchPoint = @nMatchPoint + 1 
  	     --PRINT '<>@cVasMarkForKey'
     END   
     ELSE   
     IF LEFT(@cVasMarkForKey ,2)='<>'  
        AND ISNULL(RTRIM(@cMarkForKey) ,'')<>SubString(ISNULL(RTRIM(@cVasMarkForKey),''), 3, LEN(@cVasMarkForKey) - 2)    
        AND ISNULL(RTRIM(@cVasMarkForKey) ,'')<>''  
     BEGIN
  	     SET @nMatchPoint = @nMatchPoint + 1 
  	     --PRINT '@cVasMarkForKey'
     END
                 
     IF LEFT(@cVasLottable01 ,2)<>'<>'  
        AND ISNULL(RTRIM(@cLottable01) ,'')=ISNULL(RTRIM(@cVasLottable01) ,'')  
        AND ISNULL(RTRIM(@cVasLottable01) ,'')<>''  
     BEGIN
  	     SET @nMatchPoint = @nMatchPoint + 1 
  	     --PRINT '@cVasLottable01'
     END     
     ELSE   
     IF LEFT(@cVasLottable01 ,2)='<>'  
        AND ISNULL(RTRIM(@cLottable01) ,'')<>SubString(ISNULL(RTRIM(@cVasLottable01),''), 3, LEN(@cVasLottable01) - 2)    
        AND ISNULL(RTRIM(@cVasLottable01) ,'')<>''  
     BEGIN
  	     SET @nMatchPoint = @nMatchPoint + 1 
  	     --PRINT '<>@cVasLottable01'
     END
              
     IF LEFT(@cVasLottable02 ,2)<>'<>'  
        AND ISNULL(RTRIM(@cLottable02) ,'')=ISNULL(RTRIM(@cVasLottable02) ,'')  
        AND ISNULL(RTRIM(@cVasLottable02) ,'')<>''
     BEGIN
  	     SET @nMatchPoint = @nMatchPoint+1
     END  
     ELSE   
     IF LEFT(@cVasLottable02 ,2)='<>'  
       AND ISNULL(RTRIM(@cLottable02) ,'')<>SubString(ISNULL(RTRIM(@cVasLottable02),''), 3, LEN(@cVasLottable02) - 2)   
       AND ISNULL(RTRIM(@cVasLottable02) ,'')<>''
     BEGIN
        SET @nMatchPoint = @nMatchPoint+1
     END  
          
            
     IF LEFT(@cVasLottable03 ,2)<>'<>'  
        AND ISNULL(RTRIM(@cLottable03) ,'')=ISNULL(RTRIM(@cVasLottable03) ,'')  
        AND ISNULL(RTRIM(@cVasLottable03) ,'')<>''  
     BEGIN
        SET @nMatchPoint = @nMatchPoint+1
     END  
     ELSE   
     IF LEFT(@cVasLottable03 ,2)='<>'  
        AND ISNULL(RTRIM(@cLottable03) ,'')<>SubString(ISNULL(RTRIM(@cVasLottable03),''), 3, LEN(@cVasLottable03) - 2)   
        AND ISNULL(RTRIM(@cVasLottable03) ,'')<>''  
     BEGIN
        SET @nMatchPoint = @nMatchPoint+1
     END  
            
     IF @nMatchPoint = @nTotMatchPoint  
     BEGIN  
        INSERT INTO @t_MatchHdlCode(VasKey, OrdSpecHdlgCode, MatchPoint) VALUES 
                     (@cVASKey, @cVasOrdSpecHdlgCode, @nMatchPoint)  
     END  
     
   --SELECT @nTotMatchPoint '@nTotMatchPoint', @nMatchPoint '@nMatchPoint', @cVasOrdSpecHdlgCode '@cVasOrdSpecHdlgCode', @cVasItemClass '@cVasItemClass',  
   --      @cVasCustomerID '@cVasCustomerID'  
  
       SET @nMatchPoint = 0  
        
       FETCH NEXT FROM CUR_VAS INTO @cVasVendor, @cVasBrand, @cVasDivision,   
          @cVasItemClass, @cVasSKUGroup,    @cVasCustomerID, @cVasConsigneeKey,  
          @cVasMarkForKey, @cVasLottable01, @cVasLottable02, @cVasLottable03,  
          @cVasOrdSpecHdlgCode,  @cVASKey      
   END  
    
	SET @cReturnHdlCode = ''
	SELECT TOP 1 @cReturnHdlCode = OrdSpecHdlgCode
	FROM @t_MatchHdlCode 
	ORDER BY MatchPoint DESC
	 
	RETURN @cReturnHdlCode
END

GO