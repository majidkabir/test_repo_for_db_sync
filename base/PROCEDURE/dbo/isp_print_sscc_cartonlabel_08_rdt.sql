SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store Procedure: isp_Print_SSCC_CartonLabel_08_rdt                   */    
/* Creation Date: 21-Feb-2018                                           */    
/* Copyright: IDS                                                       */    
/* Written by: CSCHONG                                                  */    
/*                                                                      */    
/* Purpose: RG_HM R9 Datawindow for SSCC Label (WMS-3353)               */    
/*                                                                      */    
/* Input Parameters: @c_orderkey - packheader.orderkey                  */    
/*                                                                      */    
/*                                                                      */    
/*                                                                      */    
/* Usage: Call by dw = r_dw_sscc_cartonlabel_08_rdt                     */    
/*                                                                      */    
/* PVCS Version: 1.3                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver.  Purposes                                */    
/* 02-11-2018   CSCHONG   1.1   WMS-6729 - revised field mapping (CS01) */  
/* 09-07-2021   CSCHONG   1.2   Performance Tunning (CS02)              */  
/************************************************************************/    
    
CREATE PROC [dbo].[isp_Print_SSCC_CartonLabel_08_rdt] (     
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
     -- @c_externOrderkey          NVARCHAR(20),    
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
          
       CREATE TABLE #TEMP_ORD08    
     (     
      OrderKey    NVARCHAR(10)   NOT NULL    
     )    
      
      
  CREATE TABLE #TEMP_SKUSIZE08 (    
    OrderKey       NVARCHAR( 30) NULL,    
    SSCC           NVARCHAR( 50) NULL,    
    SKU            NVARCHAR( 20) NULL,    
    SKUGRP         NVARCHAR( 10) NULL,    
   SColor         NVARCHAR(30)  NULL,    
    SSize          NVARCHAR(30)  NULL,    
    Lottable12     NVARCHAR( 30) NULL,    
    storerkey      NVARCHAR(20)  NULL    
   )    
      
  IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)    
              WHERE Orderkey = @c_Orderkey)    
  BEGIN    
     INSERT INTO #TEMP_ORD08 (ORDERKEY)    
     VALUES( @c_Orderkey)    
      
     SET @c_isOrdKey = '1'    
  END    
  ELSE IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)    
                 WHERE ORDERS.LOADKEY = @c_Orderkey)    
  BEGIN    
  INSERT INTO #TEMP_ORD08 (ORDERKEY)    
   SELECT DISTINCT OrderKey    
      FROM ORDERS AS OH WITH (NOLOCK)    
      WHERE OH.LOADKEY=@c_Orderkey    
   SET @c_isLoadKey = '1'    
  END    
       
       
   SET @n_cartonno = CONVERT(INT,@c_cartonno)    
       
       
   CREATE TABLE #Temp_SSCCTBL08H (    
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
       
   INSERT INTO #TEMP_SKUSIZE08 (    
    OrderKey, SSCC, SKU, SKUGRP, SColor, SSize,Lottable12,storerkey)    
    SELECT  PD.Orderkey,     
            PD.DropID AS SSCC,     
            S1.Sku,                                                            --CS02  
            S1.SKUGroup,     
            UPPER(S1.BUSR6) AS Color,     
            S1.BUSR7 AS SIZE,                                                  --CS02   
            L.Lottable12 ,PD.Storerkey    
    FROM  PickDetail PD WITH (NOLOCK)      
    --JOIN SKU (NOLOCK) AS S ON substring(pd.sku,1,10) = substring(s.sku,1,10)    --CS02  
    JOIN SKU (NOLOCK) AS S1 ON pd.sku = s1.sku      
    LEFT JOIN LOTATTRIBUTE (NOLOCK) AS L ON PD.Lot = L.Lot AND pd.sku=l.Sku    
    JOIN #TEMP_ORD08 T08 ON T08.OrderKey = Pd.OrderKey     
  --WHERE PD.Orderkey = @c_getOrdKey     
    GROUP BY  PD.Orderkey,     
              PD.DropID ,     
              S1.Sku,                                                       --CS02  
              S1.SKUGroup,     
              UPPER(S1.BUSR6) ,     
              S1.BUSR7 ,                                                    --CS02  
              L.Lottable12 ,PD.Storerkey    
    ORDER BY PD.Orderkey,     
             PD.DropID ,     
             s1.Sku                                                          --CS02  
      
  --SELECT * FROM #TEMP_SKUSIZE08        
       
       
   DECLARE CUR_ORDKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT Orderkey    
      FROM  #TEMP_ORD08    
      ORDER BY Orderkey    
    
   OPEN CUR_ORDKEY    
    
   FETCH NEXT FROM CUR_ORDKEY INTO @c_getOrdKey    
   WHILE @@FETCH_STATUS = 0    
   BEGIN    
    
         INSERT INTO #Temp_SSCCTBL08H    
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
         SELECT MIN(ISNULL(C2.short,'')) + UPPER(PH.ConsigneeKey) AS WarehouseID,     
            UPPER(C.Country)+MAX(ISNULL(C1.code,'')),     
            PD.Orderkey,     
            PD.Sku,    
            L.Lottable12 AS hmOrderNo,    
            PD.DropID AS SSCC,     
            SUBSTRING(L.Lottable01,6,1) AS Season,         
            PD.SKUGROUP,     
            PKD.CartonNo,    
            PD.scolor,     
            '',--TS08.SSize AS Size,    
            SUM(PD.Qty) AS Qty    
            -- FROM PickDetail (NOLOCK) AS PD       
            FROM ( select OrderKey , OrderLineNumber , PickDetail.StorerKey , sum(qty) [Qty] , DropID , PickDetail.SKU ,LOT    
                        ,s.SKUGROUP,UPPER(S.BUSR6) AS Scolor    
            from PickDetail (nolock)     
            JOIN sku s (NOLOCK) ON s.StorerKey=PickDetail.StorerKey AND s.sku = PickDetail.sku    
            where OrderKey = @c_Orderkey    
            group by OrderKey , OrderLineNumber , PickDetail.StorerKey , Dropid , PickDetail.SKU , LOT    
                  ,s.skugroup,UPPER(S.BUSR6)    
         ) PD    
       LEFT JOIN LOTATTRIBUTE (NOLOCK) AS L ON PD.Lot = L.Lot AND pd.sku=l.Sku    
       JOIN STORER (NOLOCK) AS C ON PD.StorerKey = C.StorerKey    
       LEFT JOIN PackHeader (NOLOCK) AS PH ON PD.Orderkey = PH.OrderKey    
       JOIN SKU (NOLOCK) AS S ON pd.StorerKey=S.StorerKey AND pd.sku = s.Sku--substring(pd.sku,1,10) = substring(s.sku,1,10)    
      -- JOIN #TEMP_SKUSIZE08 TS08 ON TS08.OrderKey=PD.OrderKey AND TS08.SKU = PD.SKU AND TS08.SSCC=PD.DropID    
       LEFT JOIN --PackDetail (NOLOCK) AS PKD ON PH.PickSlipNo = PKD.PickSlipNo AND PD.sku = PKD.sku      
          ( select distinct PickSlipNo , CartonNo , LabelNo , StorerKey     
            from PackDetail(nolock)    
            where PickSlipNo in (select PickSlipNo from PackHeader(nolock) where OrderKey = @c_Orderkey )    
          ) PKD ON PD.DropID = PKD.LabelNo   
      /*CS01 Start*/  
      LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON C2.listname = 'HMWHCode' AND C2.code=PH.ConsigneeKey and c2.storerkey = PD.StorerKey  
      LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.listname = 'HMFAC' and c1.storerkey = PD.StorerKey  
      /*CS01 End*/        
         WHERE PD.Orderkey = @c_getOrdKey --0000554539  --0000502352    
         GROUP BY PH.ConsigneeKey, PD.Orderkey, C.Country, PD.DropID, PD.Sku, L.Lottable01, L.Lottable12,PKD.CartonNo     
           , PD.SKUGROUP, PD.scolor    
           -- TS08.SKUGRP,PKD.CartonNo,TS08.Scolor,TS08.SSize,PD.qty    
          ORDER BY PD.OrderKey,PKD.CartonNo, L.Lottable12, PD.Sku, L.Lottable01 ASC     
    
    
 FETCH NEXT FROM CUR_ORDKEY INTO @c_getOrdKey    
 END    
 CLOSE CUR_ORDKEY    
 DEALLOCATE CUR_ORDKEY    
       
       
/* SELECT WarehouseID,STCountry, OrderKey, substring(SKU,1,7) AS caster, substring(SKU,8,3) AS Article ,     
         Lottable12, SSCC, Season, SKUGRP, cast(CartonNo AS NVARCHAR(10)) AS Cartonno,SUM(pqty) AS PQty,scolor AS Color,    
         CASE WHEN COUNT(SSize) = 1 THEN 'S' ELSE 'M' END AS SGRP      
  FROM #Temp_SSCCTBL08H     
  GROUP BY WarehouseID,STCountry, OrderKey, substring(SKU,1,7) , substring(SKU,8,3)  ,     
         Lottable12, SSCC, Season, SKUGRP, CartonNo,scolor    
  ORDER BY OrderKey,CartonNo    
     
         
   SELECT ts.ssize AS skusize,ts.SColor AS skuscolor,SUM(ISNULL(ts2.pqty,0)) AS skuqty,ts.sscc    
   FROM #TEMP_SKUSIZE08 AS ts     
   FULL JOIN #Temp_SSCCTBL08H AS ts2 WITH (NOLOCK) ON ts2.OrderKey=ts.OrderKey    
                                     AND ts2.SSCC=ts.SSCC    
                                     AND ts2.SKU=ts.SKU    
   --WHERE ts.orderkey=@c_orderkey    
   --AND ts2.cartonno = @n_cartonno    
   --AND ts2.Lottable12  = @c_Lot12     
   GROUP BY ts.scolor,ts.ssize,ts.sscc    
   ORDER BY ts.scolor,ts.ssize    
       
   GOTO QUIT_SP*/    
       
   IF @c_DWCategory = 'D'    
   BEGIN    
      GOTO Detail    
   END    
    
  SELECT WarehouseID,STCountry, OrderKey, substring(SKU,1,7) AS caster, substring(SKU,8,3) AS Article ,     
         Lottable12, SSCC, Season, SKUGRP, cast(CartonNo AS NVARCHAR(10)) AS Cartonno,SUM(pqty) AS PQty,scolor AS sColor,    
         CASE WHEN COUNT(SSize) = 1 THEN 'S' ELSE 'M' END AS SGRP      
  FROM #Temp_SSCCTBL08H     
  WHERE CartonNo = CASE WHEN ISNULL(@c_CartonNo,'') <> '' THEN @c_CartonNo ELSE CartonNo END    
  GROUP BY WarehouseID,STCountry, OrderKey, substring(SKU,1,7) , substring(SKU,8,3)  ,     
         Lottable12, SSCC, Season, SKUGRP, CartonNo,scolor    
  ORDER BY OrderKey,CartonNo    
      
  GOTO QUIT_SP    
   
    
  DETAIL:    
      
-- SELECT SSize,sku,Lottable12,sscc from #TEMP_SKUSIZE08    
-- WHERE Lottable12=@c_Lot12    
-- GROUP BY  SSize,sku,Lottable12,sscc    
-- ORDER BY RIGHT(sku,3)    
     
     
-- SELECT * FROM #Temp_SSCCTBL08H AS ts    
-- WHERE ts.Lottable12=@c_Lot12    
-- --AND ts.CartonNo=@c_cartonno    
                          
          
-- SELECT t8.SSize,ts.sku,t8.Lottable12,t8.sku,ts.pqty    
-- from #Temp_SSCCTBL08H ts    
-- RIGHT OUTER JOIN #TEMP_SKUSIZE08 t8 ON ts.SKU=t8.SKU    
-- and t8.OrderKey=ts.OrderKey    
--AND t8.SSCC=ts.SSCC AND ts.Lottable12=t8.Lottable12    
-- --LEFT JOIN #Temp_SSCCTBL08H AS ts ON ts.SKU=t8.SKU    
-- WHERE t8.sscc=@c_Lot12    
-- --AND ts.CartonNo = @c_cartonno      
-- --GROUP BY  t8.SSize,ts.sku,t8.Lottable12,t8.SKU,ts.pqty,ts.sscc    
-- ORDER BY RIGHT(t8.sku,3)                    
    
    
  SELECT t8.SSize AS skusize,    
  case when isnull(ts.pqty,0)>0 then ts.pqty else 0 END sizeqty--.sku,t8.Lottable12,t8.sku,ts.pqty    
  from #Temp_SSCCTBL08H ts     
  RIGHT OUTER JOIN #TEMP_SKUSIZE08 t8 ON ts.SKU=t8.SKU    
  and t8.OrderKey=ts.OrderKey    
  AND t8.SSCC=ts.SSCC AND ts.Lottable12=t8.Lottable12    
 --LEFT JOIN #Temp_SSCCTBL08H AS ts ON ts.SKU=t8.SKU    
 WHERE t8.sscc=@c_Lot12    
 --AND ts.CartonNo = @c_cartonno      
 --GROUP BY  t8.SSize,ts.sku,t8.Lottable12,t8.SKU,ts.pqty,ts.sscc    
 ORDER BY RIGHT(t8.sku,3)        
    
   GOTO QUIT_SP    
    
 --DROP TABLE @Temp_SSCCTBLH    
     
 --  DROP TABLE @Temp_SSCCTBLDET    
    
       
 QUIT_SP:    
    
END    

GO