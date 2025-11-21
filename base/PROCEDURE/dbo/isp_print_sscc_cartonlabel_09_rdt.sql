SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure: isp_Print_SSCC_CartonLabel_09_rdt                   */  
/* Creation Date: 02-MAR-2021                                           */  
/* Copyright: IDS                                                       */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-16447 CN_HM CR - Datawindow for SSCC Label              */  
/*                                                                      */  
/* Input Parameters: @c_orderkey - packheader.orderkey                  */  
/*                                                                      */  
/*                                                                      */  
/*                                                                      */  
/* Usage: Call by dw = r_dw_sscc_cartonlabel_09_rdt                     */  
/*                                                                      */  
/* PVCS Version: 1.3                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_Print_SSCC_CartonLabel_09_rdt] (   
   @c_Orderkey      NVARCHAR( 30)  
  ,@c_CartonNo      NVARCHAR(10) = ''   
  ,@c_DWCategory    NVARCHAR(1) = 'H'  
 -- ,@c_cartonno      NVARCHAR(10)= '1'  
  ,@c_Lot12         NVARCHAR(30)= ''  
   )  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
  
   DECLARE  
      @b_debug                int  
  
   DECLARE   
      @c_ShipTo_StorerKey        NVARCHAR( 15),  
      @c_ShipTo_Comapnay         NVARCHAR( 45),  
      @c_ShipTo_Addr1            NVARCHAR( 45),  
      @c_ShipTo_Addr2            NVARCHAR( 45),  
      @c_ShipTo_Addr3            NVARCHAR( 45),  
      @c_ShipTo_Zip              NVARCHAR( 18),  
      @n_CntSKU                  int,  
      @c_SKU                     NVARCHAR( 20),  
      @c_Storerkey               NVARCHAR(15),  
      @c_PID                     NVARCHAR(20),  
      @c_SKUDESCR                NVARCHAR(150),  
      @n_CntCaseid               INT,  
      @n_grosswgt                Float,  
      @n_Pqty                    INT,  
      @n_TTLGrossWgt             INT ,  
      @n_Casecnt                 float,  
      @c_lottable01              NVARCHAR(18),  
      @n_Caseqty                 INT,  
      @n_NoOfLine                INT               
     ,@c_isLoadKey               NVARCHAR(1)  
     ,@c_isOrdKey                NVARCHAR(1)  
     ,@c_getOrdKey               NVARCHAR(20)  
     ,@n_cartonno                INT  
        
        
       SET @n_NoOfLine = 6                 
       SET @c_isOrdKey = '0'   
       SET @c_isLoadKey = '0'  
        
       CREATE TABLE #TEMP_ORD09  
     (   
      OrderKey    NVARCHAR(10)   NOT NULL  
     )  
    
    
  CREATE TABLE #TEMP_SKUSIZE09 (  
    OrderKey       NVARCHAR( 30) NULL,  
    SSCC           NVARCHAR( 50) NULL,  
    SKU            NVARCHAR( 20) NULL,  
    SKUGRP         NVARCHAR( 10) NULL,  
    SColor         NVARCHAR(30)  NULL,  
    SSize          NVARCHAR(30)  NULL,  
    Lottable12     NVARCHAR( 30) NULL,  
    storerkey      NVARCHAR(20)  NULL,
    CartonNo       INT           NULL  
   )  
    
  IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)  
              WHERE Orderkey = @c_Orderkey)  
  BEGIN  
     INSERT INTO #TEMP_ORD09 (ORDERKEY)  
     VALUES( @c_Orderkey)  
    
     SET @c_isOrdKey = '1'  
  END  
  ELSE IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)  
                 WHERE ORDERS.LOADKEY = @c_Orderkey)  
  BEGIN  
   INSERT INTO #TEMP_ORD09 (ORDERKEY)  
   SELECT DISTINCT OrderKey  
   FROM ORDERS AS OH WITH (NOLOCK)  
   WHERE OH.LOADKEY=@c_Orderkey  
   SET @c_isLoadKey = '1'  
  END  
     
     
   SET @n_cartonno = CONVERT(INT,@c_cartonno)  

--select @n_cartonno '@n_cartonno'
     
     
   CREATE TABLE #Temp_SSCCTBL09H (  
         WarehouseID    NVARCHAR( 45) NULL,  
         STCountry      NVARCHAR( 45) NULL,  
         OrderKey       NVARCHAR( 30) NULL,  
         SKU            NVARCHAR( 20) NULL,  
         Lottable12     NVARCHAR( 30) NULL,   
         SSCC           NVARCHAR( 50) NULL,  
         Season         NVARCHAR( 5)  NULL,  
         SKUGRP         NVARCHAR( 10) NULL,  
         CartonNo       INT,  
         SColor         NVARCHAR(30) NULL,  
         SSize          NVARCHAR(30) NULL,  
         PQty           INT  
   )  
     
  -- SELECT * FROM #TEMP_ORD08  
     
   INSERT INTO #TEMP_SKUSIZE09 (  
    OrderKey, SSCC, SKU, SKUGRP, SColor, SSize,Lottable12,storerkey,CartonNo)  
    SELECT  packheader.Orderkey,   
            PackDetail.labelno AS SSCC,   
            PackDetail.Sku,  
            S.SKUGroup,   
            UPPER(S.BUSR6) AS Color,   
            S.BUSR7 AS SIZE,  
            PackDetail.upc ,PackDetail.Storerkey , PackDetail.CartonNo  
    --FROM  PickDetail PD WITH (NOLOCK)   
    FROM PackHeader WITH (NOLOCK)
    JOIN PackDetail (nolock) ON Packdetail.Pickslipno = Packheader.Pickslipno  
    JOIN SKU (NOLOCK) AS S ON PackDetail.sku = s.sku AND S.storerkey = PackDetail.Storerkey   
   -- LEFT JOIN LOTATTRIBUTE (NOLOCK) AS L ON PD.Lot = L.Lot AND pd.sku=L.Sku AND PD.Storerkey = L.Storerkey   
    JOIN #TEMP_ORD09 T09 ON T09.OrderKey = PackHeader.OrderKey    
    where PackDetail.Cartonno = CASE WHEN @n_cartonno <> 0 THEN @n_cartonno ELSE Cartonno END  
    GROUP BY  PackHeader.Orderkey,   
              PackDetail.labelno ,   
              PackDetail.Sku,  
              S.SKUGroup,   
              UPPER(S.BUSR6) ,   
              S.BUSR7 ,  
              PackDetail.upc ,PackDetail.Storerkey  , PackDetail.CartonNo 
    ORDER BY PackHeader.Orderkey,   
             PackDetail.labelno ,  PackDetail.CartonNo  ,
             PackDetail.Sku  

   DECLARE CUR_ORDKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT Orderkey  
      FROM  #TEMP_ORD09  
      ORDER BY Orderkey  
  
   OPEN CUR_ORDKEY  
  
   FETCH NEXT FROM CUR_ORDKEY INTO @c_getOrdKey  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
  
         INSERT INTO #Temp_SSCCTBL09H  
            (    WarehouseID ,  
                 STCountry   ,  
                 OrderKey    ,  
                 SKU         ,  
                 Lottable12  ,   
                 SSCC        ,  
                 Season      ,  
                 SKUGRP      ,  
                 CartonNo    ,  
                 SColor, SSize, PQty)                  
         SELECT MIN(ISNULL(C2.short,'')) + UPPER(Packheader.ConsigneeKey) AS WarehouseID,   
            UPPER(C.Country)+MAX(ISNULL(C1.code,'')),   
            packheader.Orderkey,   
            PackDetail.Sku,  
            PackDetail.upc AS hmOrderNo,  
            PackDetail.labelno AS SSCC,   
            SUBSTRING(PackDetail.upc,21,1) AS Season,       
            S.SKUGROUP,   
            PackDetail.CartonNo,  
            UPPER(S.BUSR6),   
            '',
            SUM(PackDetail.Qty) AS Qty  
            -- FROM PickDetail (NOLOCK) AS PD     
       FROM  PackHeader WITH (NOLOCK)
       JOIN PackDetail (nolock) ON Packdetail.Pickslipno = Packheader.Pickslipno    
       JOIN STORER (NOLOCK) AS C ON PackHeader.StorerKey = C.StorerKey  
      -- LEFT JOIN PackHeader (NOLOCK) AS PH ON PD.Orderkey = PH.OrderKey  
       JOIN SKU (NOLOCK) AS S ON PackDetail.StorerKey=S.StorerKey AND PackDetail.sku = s.Sku
      LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON C2.listname = 'HMWHCode' AND C2.code=PackHeader.ConsigneeKey and c2.storerkey = PackHeader.StorerKey
      LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.listname = 'HMFAC' and c1.storerkey = PackHeader.StorerKey    
      WHERE PackHeader.Orderkey = @c_getOrdKey 
      AND PackDetail.Cartonno = CASE WHEN @n_cartonno <> 0 THEN @n_cartonno ELSE Cartonno END 
      GROUP BY PackHeader.ConsigneeKey, PackHeader.Orderkey, C.Country, PackDetail.labelno, PackDetail.Sku, SUBSTRING(PackDetail.upc,21,1),PackDetail.CartonNo   
             , S.SKUGROUP, UPPER(S.BUSR6) ,PackDetail.upc
      ORDER BY PackHeader.OrderKey,PackDetail.CartonNo, PackDetail.upc, PackDetail.Sku ASC   
  
  
 FETCH NEXT FROM CUR_ORDKEY INTO @c_getOrdKey  
 END  
 CLOSE CUR_ORDKEY  
 DEALLOCATE CUR_ORDKEY  
    
     
   IF @c_DWCategory = 'D'  
   BEGIN  
      GOTO Detail  
   END  
  
  SELECT WarehouseID,STCountry, OrderKey, substring(SKU,1,7) AS caster, substring(SKU,8,3) AS Article ,   
         substring(Lottable12,22,6) as Lottable12, SSCC, Season, SKUGRP, cast(CartonNo AS NVARCHAR(10)) AS Cartonno,SUM(pqty) AS PQty,scolor AS sColor,  
         CASE WHEN COUNT(SSize) = 1 THEN 'S' ELSE 'M' END AS SGRP    
  FROM #Temp_SSCCTBL09H   
  WHERE CartonNo = CASE WHEN ISNULL(@c_CartonNo,'') <> '' THEN @c_CartonNo ELSE CartonNo END  
  GROUP BY WarehouseID,STCountry, OrderKey, substring(SKU,1,7) , substring(SKU,8,3)  ,   
         Lottable12, SSCC, Season, SKUGRP, CartonNo,scolor  
  ORDER BY OrderKey,CartonNo  

--select * from #Temp_SSCCTBL09H
--select * from #TEMP_SKUSIZE09
    
  GOTO QUIT_SP  
    

  
  DETAIL:      
  

  
  SELECT t9.SSize AS skusize,  
  case when isnull(ts.pqty,0)>0 then ts.pqty else 0 END sizeqty
  from #Temp_SSCCTBL09H ts   
  RIGHT OUTER JOIN #TEMP_SKUSIZE09 t9 ON ts.SKU=t9.SKU  and ts.CartonNo=t9.CartonNo
  and t9.OrderKey=ts.OrderKey  
  AND t9.SSCC=ts.SSCC AND ts.Lottable12=t9.Lottable12   
 WHERE  ts.cartonno = CAST(@c_CartonNo AS INT)
 ORDER BY RIGHT(t9.sku,3)      
  
   GOTO QUIT_SP 
     
 QUIT_SP:  
  
END  

GO