SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Stored Procedure: isp_DysonGenTransZO                                */      
/* Creation Date: 28-May-2020                                           */      
/* Copyright: LF Logistics                                              */      
/* Written by: TLTING                                                   */      
/*                                                                      */      
/* Purpose:                                                             */      
/*                                                                      */      
/* Called By:                                                           */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 1.0                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author  Rev   Purposes                                  */      
/* 28-May-2020  TLTING  1.0   Initital                                  */     
/* 01-Aug-2023  gywong  1.1   CR https://jiralfl.atlassian.net/browse/WMS-22862 */   
/* 04-Aug-2023  KuanYee 1.2   INC2134056-AddOn filter (KY01)            */  
/************************************************************************/    
  
CREATE   PROC [dbo].[isp_DysonGenTransZO] (  
   @c_storerkey NVARCHAR(18) = 'DYSON'  
)  
AS   
BEGIN  
  
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    
  
DECLARE  @c_orderkey  NVARCHAR(10) = '',   
      @c_tablename NVARCHAR(30),  
	  @c_udf03 NVARCHAR(30)= ''

--SET  @c_storerkey = 'DYSON'
--SET @c_tablename = 'WSCRSOADDZO'


  
IF EXISTS (  SELECT 1   
             FROM orders a (NOLOCK)   
             WHERE a.storerkey = @c_storerkey   
             AND a.doctype = 'E'   
             AND a.status NOT IN ('9', 'CANC')  
             AND A.SOSTATUS <> 'PENDCANC'          --KY01
             AND ISNULL(a.TrackingNo, '') = ''         --KY01
             AND a.shipperkey = 'ZTO'  
             AND NOT EXISTS ( SELECT 1 FROM Transmitlog2 c(NOLOCK)   
                     WHERE c.key3 = a.storerkey    
                     AND c.key1 = a.orderkey
					 AND c.transmitflag IN ('0','1')
                      )           
                     )  
BEGIN  
   DECLARE OrdItems_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
    SELECT orderkey   
    FROM Orders a (NOLOCK)   
    WHERE a.storerkey = @c_storerkey   
    AND a.doctype = 'E'   
    AND a.status NOT IN ('9', 'CANC')  
    AND A.SOSTATUS <> 'PENDCANC'          --KY01
    AND ISNULL(a.userdefine04, '') = ''       --KY01
    AND a.shipperkey = 'ZTO'  
    AND NOT EXISTS ( SELECT 1 FROM Transmitlog2 c(NOLOCK)   
            WHERE c.key3 = a.storerkey    
            AND c.key1 = a.orderkey
			AND c.transmitflag IN ('0','1')
             )  
  
    OPEN OrdItems_cur  
  
    FETCH NEXT FROM OrdItems_cur INTO @c_orderkey   
    WHILE @@FETCH_STATUS=0  
    BEGIN   
		
		SELECT  @c_udf03 = c.UDF03
	FROM dbo.orders o (NOLOCK)
	JOIN dbo.CODELKUP  c (NOLOCK) ON o.ECOM_Platform = c.Short AND o.OrderKey = @c_orderkey
	WHERE c.LISTNAME = 'DYSONSTORE'

	 IF @c_udf03 IS NULL 
	 BEGIN 
	  SET @c_tablename = 'WSCRSOADDZO'
	 END
	 ELSE IF  @c_udf03 = ''
	  BEGIN
	  SET @c_tablename = 'WSCRSOADDZO'
	  END

	  ELSE 
	  BEGIN
	  SET @c_tablename = @c_udf03
	  END 

  
       EXEC ispGenTransmitLog2 @c_tablename, @c_orderkey, '0', @c_storerkey, '', 0, 0,''   
                                    
      FETCH NEXT FROM OrdItems_cur INTO @c_orderkey   
    END  
   
   CLOSE OrdItems_cur   
   DEALLOCATE OrdItems_cur  
END   
   
END  

GO