SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_TPB_Inventory_UA                               */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: TPB billing for UA DailyInventory Transaction               */      
/*                                                                      */      
/* Called By:  isp_TPBExtract                                           */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author    Ver.  Purposes                                */   
/* 2018Jan29    TLTING    1.1   Inv datetime -1 Mi - Oracle issue on 00 */  
/* 08-Jun-18    TLTING    1.2   pass in billdate                        */    
/************************************************************************/  



CREATE PROC [dbo].[isp_TPB_Inventory_UA]
@n_WMS_BatchNo BIGINT,
@n_TPB_Key BIGINT,
@d_BillDate Date,
@n_RecCOUNT INT = 0 OUTPUT,
@c_Storerkey NVARCHAR(15),
@n_debug INT = 0 
AS
BEGIN
   SET CONCAT_NULL_YIELDS_NULL OFF    
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF    
   SET NOCOUNT ON    
       
   Declare @d_Todate DATETIME
   Declare @d_Fromdate DATETIME
   Declare @c_COUNTRYISO nvarchar(5)
   
   DECLARE @c_SQLStatement       NVARCHAR(MAX),
              @c_SQLParm         NVARCHAR(4000),
              @c_SQLCondition    NVARCHAR(4000),
              @c_SQLGroup        NVARCHAR(4000),
              @c_SQLGroup1       NVARCHAR(4000),
              @c_SQLGroup2       NVARCHAR(4000)
   
   -- format date filter yesterday full day
   SET @d_Fromdate = @d_BillDate -- CONVERT(CHAR(11), GETDATE() - 1 , 120)
   SELECT @d_Todate = CONVERT(CHAR(11), @d_Fromdate , 120) + '23:59:59:998'
   SET @n_RecCOUNT = 0
   
   --   3 char CountryISO code
   SELECT @c_COUNTRYISO = UPPER(ISNULL(RTRIM(NSQLValue), '')) FROM dbo.NSQLCONFIG (NOLOCK) WHERE ConfigKey = 'CountryISO'
   
   -- filtering condition 
   SELECT @c_SQLCondition = ISNULL(SQLCondition,'') FROM TPB_Config WITH (NOLOCK) WHERE TPB_Key = @n_TPB_Key   
   
   -- format the filtering condition   
   IF ISNULL(RTRIM(@c_SQLCondition) ,'') <> ''
   BEGIN
      SET @c_SQLCondition = ' AND ' + @c_SQLCondition 
   END
   

   -- Dynamic SQL


   SET @c_SQLStatement = 
   ' SELECT @n_WMS_BatchNo ' +
     ',@n_TPB_Key '+
     ',''S'' ' +            --  S = STORAGE
     ',''INVENTORY'' ' +
     ',@c_COUNTRYISO ' +
     ',Daily.Facility ' +
     ',''WMS'' ' + 
     ',''I'' ' +
     ',Daily.Storerkey ' +
     ',Daily.InventoryDate ' +               --  REFERENCE_DATE
     ',SUM(Daily.OnHandQty) ' + 
     ',COUNT(DISTINCT Daily.Lottable11) ' +
     ',SUM(CASE WHEN Daily.userdefined04 = 0.0 THEN LooseWeight ELSE Daily.userdefined04 END ) ' +
     ',SUM(CASE WHEN Daily.Locationtype=''DYNPPICK'' THEN LooseCBM WHEN ISNULL(Daily.userdefined08,0) = 0 THEN LooseCBM ELSE Daily.userdefined08 END) ' +
     ',DATEADD(MINUTE, -1, Daily.InventoryDate) ' +                -- BILLABLE_DATE
     'FROM ( SELECT Convert(datetime, Convert(char(11), DI.InventoryDate, 120) + '' 23:59:00'' ) as InventoryDate ' +
            ',UPPER(RTRIM(DI.Facility)) as Facility' +
            ',UPPER(RTRIM(DI.StorerKey)) as StorerKey ' +
            ',RTRIM(L.Lottable11) as Lottable11 ' +
            ',SUM( DI.Qty ) AS OnHandQty ' +
            ',ISNULL(UT.Userdefined04, 0.0) as Userdefined04 ' +
            ',ISNULL(UT.userdefined08, 0.0) as userdefined08 ' +
            ',SUM ( DI.Qty * S.STDGROSSWGT ) AS LooseWeight ' +
            ',SUM ( DI.Qty * S.STDCUBE ) AS LooseCBM ' +
            ',LOC.LocationType ' +
            'FROM dbo.DailyInventory DI (NOLOCK) ' +
            'JOIN dbo.SKU S (NOLOCK) ON S.StorerKey = DI.Storerkey AND S.SKU = DI.SKU ' +
            'JOIN dbo.LOTATTRIBUTE L (NOLOCK) ON L.LOT = DI.Lot ' +
            'JOIN dbo.LOC LOC (NOLOCK) ON DI.LOC=LOC.LOC ' +
            'LEFT OUTER JOIN ( SELECT A.Storerkey AS storerkey ' +
                              ',A.UCCNo as uccno ' +
                              ',MAX( CONVERT(FLOAT, CASE WHEN ISNUMERIC(A.Userdefined04)=1 THEN A.userdefined04 ELSE '''' END) ) as userdefined04 ' +
                              ',MAX( CONVERT(FLOAT, CASE WHEN ISNUMERIC(A.Userdefined08)=1 THEN A.userdefined08 ELSE '''' END) ) as userdefined08 ' +
                              ',A.Userdefined02 As Userdefined02 ' +
                              'FROM dbo.UCC A (NOLOCK) ' +
                              'WHERE A.Storerkey= @c_storerkey '  + 
                               ' GROUP BY A.Storerkey ' +
                                 ',A.UCCNo ,A.Userdefined02  ) ' +
                              'AS UT ON UT.uccno = L.Lottable11 and UT.Userdefined02=L.Lottable03 ' + 
            'WHERE DI.Storerkey = @c_storerkey ' +
            'AND DI.Qty > 0 ' + 
            'AND DI.InventoryDate between @d_Fromdate and @d_Todate ' +
             ' GROUP BY Convert(datetime, Convert(char(11), DI.InventoryDate, 120) + '' 23:59:00'' ) ' +
                         ',UPPER(RTRIM(DI.Facility)) ' +
                         ',UPPER(RTRIM(DI.StorerKey)) ' +
                         ',RTRIM(L.Lottable11) ' +
                         ',ISNULL(UT.Userdefined04, 0.0) ' +
                         ',ISNULL(UT.userdefined08, 0.0) ,LOC.LocationType ) ' + 'AS Daily ' + 
      ' GROUP BY Daily.InventoryDate ' +
                        ',Daily.Facility ' +
                        ',Daily.Storerkey '  


     SET @c_SQLParm = '@n_WMS_BatchNo BIGINT, @n_TPB_Key nvarchar(5), @c_COUNTRYISO Nvarchar(5), @d_Fromdate DATETIME, ' +
                     '@d_Todate DATETIME, @c_Storerkey nvarchar(15) '


      IF @n_debug = 1
      BEGIN
         PRINT 'COUNTRYISO - ' + @c_COUNTRYISO
         PRINT '@c_SQLCondition'
         PRINT @c_SQLCondition
         PRINT '@c_SQLStatement'
         PRINT @c_SQLStatement
         PRINT '@c_SQLParm'
         PRINT @c_SQLParm
      END
      
      -- INSERT Data
      INSERT INTO [DBO].[WMS_TPB_BASE](
        BatchNo 
        ,Config_id
        ,TRANSACTION_TYPE 
        ,CODE 
        ,COUNTRY 
        ,SITE_ID 
        ,DOC_SOURCE 
        ,DOC_TYPE
        ,CLIENT_ID
        ,REFERENCE_DATE
        ,BILLABLE_QUANTITY
        ,BILLABLE_CARTON
        ,BILLABLE_WEIGHT
        ,BILLABLE_CBM
        ,BILLABLE_DATE
        )
     EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParm, @n_WMS_BatchNo, @n_TPB_Key, @c_COUNTRYISO, @d_Fromdate, @d_Todate, @c_storerkey
         SET @n_RecCOUNT = @@ROWCOUNT

         IF @n_debug = 1
         BEGIN
            PRINT 'Record Count - ' + CAST(@n_RecCOUNT AS NVARCHAR)
            PRINT ''
         END 
    END

GO