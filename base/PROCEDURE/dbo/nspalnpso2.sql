SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* Stored Procedure: nspALNPSO2                                         */        
/* Creation Date: 24-AUG-2021                                           */        
/* Copyright: LFL                                                       */        
/* Written by:                                                          */        
/*                                                                      */        
/* Purpose: WMS-17792 TH Nespresso allocation (copy from nspALNPSO1)    */    
/*          SkipPreallocation = '1'  OrderInfo4Allocation  = '1'        */    
/*                                                                      */    
/* Called By: Wave                                                      */        
/*                                                                      */        
/* PVCS Version: 1.0                                                    */        
/*                                                                      */        
/* Version: 7.0                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author  Ver.  Purposes                                  */        
/* 06-Oct-2021  NJOW    1.0   DEVOPS combine script                     */  
/************************************************************************/        
CREATE   PROC [dbo].[nspALNPSO2]            
   @c_DocumentNo NVARCHAR(10),      
   @c_Facility   NVARCHAR(5),         
   @c_StorerKey  NVARCHAR(15),         
   @c_SKU        NVARCHAR(20),        
   @c_Lottable01 NVARCHAR(18),        
   @c_Lottable02 NVARCHAR(18),        
   @c_Lottable03 NVARCHAR(18),        
   @d_Lottable04 DATETIME,        
   @d_Lottable05 DATETIME,        
   @c_Lottable06 NVARCHAR(30),        
   @c_Lottable07 NVARCHAR(30),        
   @c_Lottable08 NVARCHAR(30),        
   @c_Lottable09 NVARCHAR(30),        
   @c_Lottable10 NVARCHAR(30),        
   @c_Lottable11 NVARCHAR(30),        
   @c_Lottable12 NVARCHAR(30),        
   @d_Lottable13 DATETIME,        
   @d_Lottable14 DATETIME,        
   @d_Lottable15 DATETIME,        
   @c_UOM        NVARCHAR(10),        
   @c_HostWHCode NVARCHAR(10),        
   @n_UOMBase    INT,        
   @n_QtyLeftToFulfill INT,    
   @c_OtherParms NVARCHAR(200)=''    
AS        
BEGIN        
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF        
          
   DECLARE @c_SQL                NVARCHAR(MAX),        
           @c_SQLParm            NVARCHAR(MAX),                                       
           @c_key1               NVARCHAR(10),        
           @c_key2               NVARCHAR(5),        
           @c_key3               NCHAR(1),    
           @c_Orderkey           NVARCHAR(10),         
           @n_QtyAvailable       INT,      
           @c_LOT                NVARCHAR(10),    
           @c_LOC                NVARCHAR(10),    
           @c_ID                 NVARCHAR(18),     
           @c_OtherValue         NVARCHAR(20),    
           @n_QtyToTake          INT,    
           @n_StorerMinShelfLife INT,    
           @n_LotQtyAvailable    INT,    
           @c_DocType            NVARCHAR(1),    
           @c_Lottable04Label    NVARCHAR(20),    
           @c_SkuGroup           NVARCHAR(10),  
           @C_OrderType          NVARCHAR(10),  
           @c_Wavekey            NVARCHAR(10),  
           @c_PAZones            NVARCHAR(500),  
           @c_UserDefine02       NVARCHAR(20),  
           @n_SkuMinShelfLife    INT,  
           @n_SkuShelfLife       INT,  
           @n_ShelfLife       INT,  
           @c_OrderPAzone        NVARCHAR(10), --NJOW04    
           @c_OrderPutwayzone NVARCHAR(10)  
      
   SET @n_QtyAvailable = 0              
   SET @c_OtherValue = '1'     
   SET @n_QtyToTake = 0    
       
   IF @n_UOMBase = 0    
     SET @n_UOMBase = 1    
    
   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL,    
                          QtyAvailable INT NULL DEFAULT(0))    
       
   IF LEN(@c_OtherParms) > 0     
   BEGIN    
      SET @c_OrderKey = LEFT(@c_OtherParms,10)  --if call by discrete    
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)    
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber               
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave           
          
      IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='' --call by load conso    
      BEGIN    
         SET @c_Orderkey = ''    
         SELECT TOP 1 @c_Orderkey = O.Orderkey    
         FROM ORDERS O (NOLOCK)     
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey    
         WHERE O.Loadkey = @c_key1    
         AND OD.Sku = @c_SKU    
         ORDER BY O.Orderkey, OD.OrderLineNumber    
      END                  
             
      IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='W' --call by wave conso    
      BEGIN    
         SET @c_Orderkey = ''    
         SELECT TOP 1 @c_Orderkey = O.Orderkey    
         FROM ORDERS O (NOLOCK)     
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey    
         JOIN WAVEDETAIL WD (NOLOCK) ON O.Orderkey = WD.Orderkey    
         WHERE WD.Wavekey = @c_key1    
         AND OD.Sku = @c_SKU    
         ORDER BY O.Orderkey, OD.OrderLineNumber    
      END                  
                     
      SELECT TOP 1 @c_Doctype = O.DocType,    
                   @c_OrderType = O.Type,  
                   @c_Wavekey = O.Userdefine09,  
                   @c_UserDefine02 = O.Userdefine02                       
      FROM ORDERS O (NOLOCK)    
      WHERE O.Orderkey = @c_Orderkey    
          
      SELECT @c_Lottable04Label = Lottable04Label,    
             @c_SkuGroup = SkuGroup     
      FROM SKU (NOLOCK)    
      WHERE Storerkey = @c_Storerkey    
      AND Sku = @c_Sku          
          
      /*  
      IF @c_UOM = '7' AND @c_SkuGroup NOT IN('NESCOFEE')--Case allocation only for NESCOFEE   (FEFO)  
         GOTO EXIT_SP             
    
      IF @c_UOM = '6' AND @c_SkuGroup IN('NESCOFEE') --No piece allocation for NESCOFEE   (FIFO)  
         GOTO EXIT_SP  
      */             
  
        
      IF @c_UOM = '7' AND @c_SkuGroup NOT IN('NESCOFEE')--No UOM 7 for NON NESCOFEE  
         GOTO EXIT_SP                      
      ELSE IF @c_UOM = '7' AND @c_SkuGroup IN('NESCOFEE') AND @C_OrderType = 'BQ'  --No UOM 7 BQ   
         GOTO EXIT_SP             
      ELSE IF @c_UOM = '7' AND @c_SkuGroup IN('NESCOFEE') AND @C_OrderType = 'HOME' AND @c_UserDefine02 = 'H3'  --No UOM 7 form HOME,H3  
         GOTO EXIT_SP  
  
      IF @c_UOM = '6' AND @c_SkuGroup IN('NESCOFEE') AND  NOT (@C_OrderType = 'BQ' OR (@C_OrderType = 'HOME' AND @c_UserDefine02 = 'H3'))  --No UOM 6 for NESCOFEE with Non BQ or non HOME,H3  
         GOTO EXIT_SP      
                  
   END    
     
   --Home and OOH are allocated from PTLB2CZON2, PTLB2BZONE, PTLB2CZONE. An order type can mix B2B and B2C sku  
   --B2B sku allocated from PTLB2BZONE. B2C Sku allocate from PTLB2CZONE, PTLB2CZON2 with zone swapping for cofee  
   IF @C_OrderType IN('HOME','OOH') AND @c_SkuGroup = 'NESCOFEE'  
   BEGIN    
      SELECT TOP 1 @c_OrderPutwayzone = LOC.Putawayzone  --if the order already assign with a zone   
      FROM PICKDETAIL PD (NOLOCK)   
      JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
      AND PD.Orderkey = @c_Orderkey  
        
      IF ISNULL(@c_OrderPutwayzone,'') = ''  
      BEGIN  
         SELECT TOP 1 @c_OrderPutwayzone = MAX(LOC.PutawayZone) --if one of the sku of the order only has one putawayzone then the order always fix to the zone  
         FROM ORDERDETAIL OD (NOLOCK)   
         JOIN SKUXLOC SL (NOLOCK) ON  OD.Storerkey = SL.Storerkey AND OD.Sku = SL.Sku  
         JOIN LOC (NOLOCK) ON SL.Loc = LOC.Loc                   
         WHERE LOC.Putawayzone IN ('PTLB2CZONE','PTLB2CZON2')  
         AND SL.Qty - SL.QtyAllocated - SL.QtyPicked > 0   
         AND Loc.LocationType = 'PICK'  
         AND OD.Orderkey = @c_Orderkey  
         GROUP BY OD.Sku  
         HAVING COUNT(DISTINCT LOC.Putawayzone) = 1  
      END  
        
      IF ISNULL(@c_OrderPutwayzone,'') <> ''  
      BEGIN  
        SET @c_PAZones = @c_OrderPutwayzone    
      END  
      ELSE  
      BEGIN      
         IF EXISTS (SELECT 1    
                    FROM SKUXLOC (NOLOCK)  
                    JOIN LOC (NOLOCK) ON SKUXLOC.Loc = LOC.Loc  
                    WHERE SKUXLOC.Storerkey = @c_Storerkey  
                    AND SKUXLOC.Sku = @c_Sku  
                    AND LOC.Putawayzone IN ('PTLB2CZONE','PTLB2CZON2')  
                    AND SKUXLOC.Qty - SKUXLOC.QtyAllocated - SKUXLOC.QtyPicked > 0   
                    AND Loc.LocationType = 'PICK'  
                    HAVING COUNT(DISTINCT LOC.Putawayzone) = 2)   
         BEGIN                                    
            SELECT @c_PAZones = CASE WHEN (S.rowno % 2) = 1 THEN 'PTLB2CZONE' ELSE 'PTLB2CZON2' END   
            FROM (SELECT WD.orderkey, ROW_NUMBER() OVER (ORDER BY WD.Orderkey) AS rowno  
                  FROM WAVEDETAIL WD (NOLOCK)  
                  JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
                  WHERE WD.Wavekey = @c_Wavekey  
                  AND EXISTS(SELECT 1   
                             FROM ORDERS O (NOLOCK)  
                             JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey  
                             JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku --NJOW04  
                             WHERE O.Orderkey = WD.Orderkey  
                             AND O.Type IN('HOME','OOH')  
                             AND SKU.SkuGroup = @c_SkuGroup) --NJOW04  
                             --AND OD.Sku = @c_Sku)  
                  ) S  
            WHERE S.orderkey = @c_Orderkey  
         END  
      END        
   END  
     
   --NJOW04  
   IF @C_OrderType IN('HOME','OOH') AND ISNULL(@c_PAZones,'') = ''  
   BEGIN  
      SELECT TOP 1 @c_OrderPAzone = LOC.Putawayzone   
      FROM PICKDETAIL PD (NOLOCK)   
      JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
      AND PD.Orderkey = @c_Orderkey  
        
      IF ISNULL(@c_OrderPAzone,'') <> ''  
         SET @c_PAZones = @c_OrderPAzone             
   END      
    
   --for NESCOFEE  
   IF ISNULL(@c_PAZones,'') <> ''  
      SET @c_PAZones = ' AND Loc.Putawayzone IN (''' + RTRIM(@c_PAZones) + ''')'       
   ELSE IF @C_OrderType IN('HOME','OOH')   
      SET @c_PAZones = ' AND Loc.Putawayzone IN ( ''PTLB2CZON2'', ''PTLB2BZONE'', ''PTLB2CZONE'') '  
   ELSE  
      SET @c_PAZones = ' AND Loc.Putawayzone IN ( ''AIRCON'', ''PTLB2BZONE'', ''PTLB2CZONE'',''PICK2PLTZ1'') '   --NJOW05  
     
   SET @n_ShelfLife = 0     
   SELECT TOP 1 @n_ShelfLife = CASE WHEN ISNUMERIC(UDF01) = 1 THEN CAST(UDF01 AS INT) ELSE 0 END  
   FROM CODELKUP (NOLOCK)  
   WHERE Listname = 'SKUSL'     
   AND Code2 = @c_Sku  
   AND Short = @c_OrderType  
   ORDER BY UDF01 DESC  
    
   SELECT --@n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1),  
          @n_SkuMinShelfLife = CASE WHEN ISNUMERIC(Sku.Susr2) = 1 THEN CAST(Sku.Susr2 AS INT) ELSE 0 END,  --NJOW03  
          @n_SkuShelfLife = Sku.Shelflife                                                                                                                                                                                                                      
                                                                                                                                                                                                                                                               
                                                                                                                                                                                                                                                               
                                                                                                                                                                                                                                                               
                                                                                                                                                                                                                                                               
                                                                                                                                                                                                                                                               
                                                                                                                                                                                                                                                               
                                                                                                                                                                                                                                                               
                                                                                                                                                                                                                                                               
                                                                                                                                                                                                                                                               
                                                                                                                                                                                                                                                               
                         --NJOW03  
   FROM Sku (nolock)    
   JOIN Storer (nolock) ON Sku.Storerkey = Storer.Storerkey    
   WHERE Sku.Sku = @c_sku    
   AND Sku.Storerkey = @c_storerkey       
       
   --IF @n_StorerMinShelfLife IS NULL    
      SELECT @n_StorerMinShelfLife = 0    
  
   IF @n_SkuMinShelfLife IS NULL    
      SELECT @n_SkuMinShelfLife = 0    
  
   IF @n_SkuShelfLife IS NULL    
      SELECT @n_SkuShelfLife = 0          
    
   SET @c_SQL = N'       
      DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR    
      SELECT LOTxLOCxID.LOT,    
             LOTxLOCxID.LOC,    
             LOTxLOCxID.ID,    
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen)    
      FROM LOTxLOCxID (NOLOCK)    
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)    
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)    
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT)    
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT    
      JOIN SKU (NOLOCK) ON LOTxLOCxID.Storerkey = SKU.Storerkey AND LOTxLOCxID.Sku = SKU.Sku    
      JOIN SKUXLOC SL (NOLOCK) ON (LOTxLOCxID.Storerkey = SL.Storerkey AND LOTxLOCxID.Sku = SL.Sku AND LOTxLOCxID.Loc = SL.Loc)    
     WHERE LOC.Status <> ''HOLD''    
      AND LOT.Status <> ''HOLD''    
      AND ID.Status <> ''HOLD''    
      AND LOC.Facility = @c_Facility    
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= @n_UOMBase    
      AND LOTxLOCxID.STORERKEY = @c_StorerKey    
      AND LOTxLOCxID.SKU = @c_SKU           
      AND LOC.LocationFlag = ''NONE'' ' +      
      CASE WHEN @c_SkuGroup = 'NESMACH' AND @c_Doctype = 'N' THEN ' AND Loc.LocationType = ''RESERVE'' '    
           WHEN @c_SkuGroup = 'NESCOFEE' THEN ' AND Loc.LocationType = ''PICK'' '--'IN (''OTHER'',''CASE'',''PICK'') '               
           ELSE ' AND LOC.LocationType = ''PICK'' ' END +  
      CASE WHEN @C_OrderType = 'BQ' THEN ' AND Loc.Putawayzone IN(''AMZONE'',''AIRCON'',''PICK2PLTZ1'') ' --NJOW05  
           WHEN @C_OrderType = 'HOME' AND @c_UserDefine02 = 'H3' THEN ' AND Loc.Putawayzone IN(''AMZONE'',''AIRCON'',''PICK2PLTZ1'') '  --NJOW05  
           WHEN @c_SkuGroup = 'NESCOFEE' THEN RTRIM(@c_PAZones) --' AND Loc.Putawayzone IN ( ''AIRCON'', ''PTLB2BZONE'', ''PTLB2CZONE'') '    
           WHEN @c_SkuGroup = 'NESMACH' AND @c_Doctype = 'N' THEN ' AND Loc.Putawayzone = ''VIRTUAL'' '    
           WHEN @c_SkuGroup = 'NESCOFEEB' THEN ' AND Loc.Putawayzone IN(''AIRCON'',''PICK2PLTZ1'') '  --NJOW02 NJOW05  
           ELSE ' AND LOC.Putawayzone = ''AMZONE'' ' END  +  
      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' END +    
      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' END +    
      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' END +    
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LA.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END +          
      CASE WHEN @n_ShelfLife <> 0 THEN ' AND DATEDIFF(day, GETDATE(), LA.Lottable04) >= ' + CAST(@n_ShelfLife AS NVARCHAR(10)) + ' ' ELSE ' ' END +  
      ----CASE WHEN @n_StorerMinShelfLife <> 0 THEN ' AND DateAdd(Day, ' + CAST(@n_StorerMinShelfLife AS NVARCHAR(10)) + ', LA.Lottable04) > GetDate() '  
        --CASE WHEN @n_SkuMinShelfLife <> 0 THEN ' AND DateAdd(Day, ' + CAST(@n_SkuMinShelfLife AS NVARCHAR(10)) +   
        --', CASE WHEN ISDATE(SUBSTRING(LA.Lottable03,7,4) +  SUBSTRING(LA.Lottable03,4,2) + LEFT(LA.Lottable03,2))=1 THEN CONVERT(DATETIME,SUBSTRING(LA.Lottable03,7,4) +  SUBSTRING(LA.Lottable03,4,2) + LEFT(LA.Lottable03,2)) ELSE GETDATE() END) > GetDate() '--NJOW03  
        --     WHEN @n_SkuShelfLife <> 0 THEN ' AND DateAdd(Day, ' + CAST(@n_SkuShelfLife AS NVARCHAR(10)) +   
        --       ', CASE WHEN ISDATE(SUBSTRING(LA.Lottable03,7,4) +  SUBSTRING(LA.Lottable03,4,2) + LEFT(LA.Lottable03,2))=1 THEN CONVERT(DATETIME,SUBSTRING(LA.Lottable03,7,4) +  SUBSTRING(LA.Lottable03,4,2) + LEFT(LA.Lottable03,2)) ELSE GETDATE() END) > GetDate() '--NJOW03  
        --     ELSE ' ' END +     
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LA.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END +    
      CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' END +    
      CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' END +    
      CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' END +    
      CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' END +    
      CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' END +    
      CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' END +    
      --CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' END +    
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LA.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END +    
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LA.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END +    
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LA.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END +    
      ' ORDER BY CASE WHEN SKU.Lottable04Label = ''EXP_DATE'' AND SKU.SkuGroup <> ''NESMACH'' THEN LA.Lottable04 ELSE NULL END, LA.Lottable05, LA.Lot, LOC.LogicalLocation, LOC.LOC '        
    
   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, @n_UOMBase INT, ' +    
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +    
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +    
                      '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME '     
     
     
   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @n_UOMBase, @c_Lottable01, @c_Lottable02, @c_Lottable03,    
                      @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,    
                      @d_Lottable13, @d_Lottable14, @d_Lottable15    
    
   SET @c_SQL = ''    
   SET @n_LotQtyAvailable = 0    
    
   OPEN CURSOR_AVAILABLE                        
   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable       
              
   WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)              
   BEGIN        
    
      IF NOT EXISTS(SELECT 1 FROM #TMP_LOT WHERE Lot = @c_Lot)    
      BEGIN    
        INSERT INTO #TMP_LOT (Lot, QtyAvailable)    
        SELECT Lot, Qty - QtyAllocated - QtyPicked    
        FROM LOT (NOLOCK)    
        WHERE LOT = @c_LOT             
      END    
      SET @n_LotQtyAvailable = 0    
    
      SELECT @n_LotQtyAvailable = QtyAvailable    
      FROM #TMP_LOT     
      WHERE Lot = @c_Lot          
          
      IF @n_LotQtyAvailable < @n_QtyAvailable     
      BEGIN    
        IF @c_UOM = '1'     
           SET @n_QtyAvailable = 0    
        ELSE    
            SET @n_QtyAvailable = @n_LotQtyAvailable    
      END    
                                      
      IF @n_QtyLeftToFulfill >= @n_QtyAvailable    
      BEGIN    
         SET @n_QtyToTake = Floor(@n_QtyAvailable / @n_UOMBase) * @n_UOMBase    
      END    
      ELSE    
      BEGIN    
         SET @n_QtyToTake = Floor(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase    
      END            
          
      IF @n_QtyToTake > 0    
      BEGIN    
        UPDATE #TMP_LOT    
        SET QtyAvailable = QtyAvailable - @n_QtyToTake     
        WHERE Lot = @c_Lot    
           
         IF ISNULL(@c_SQL,'') = ''    
         BEGIN    
            SET @c_SQL = N'       
                  DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR       
                  SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''    
                  '    
         END    
         ELSE    
         BEGIN    
            SET @c_SQL = @c_SQL + N'      
                  UNION ALL    
                  SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''    
                  '    
         END    
         SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake           
      END    
                
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable      
   END -- END WHILE FOR CURSOR_AVAILABLE              
    
   EXIT_SP:    
    
   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') in (0 , 1)              
   BEGIN              
      CLOSE CURSOR_AVAILABLE              
      DEALLOCATE CURSOR_AVAILABLE              
   END        
    
   IF ISNULL(@c_SQL,'') <> ''    
   BEGIN    
      EXEC sp_ExecuteSQL @c_SQL    
   END    
   ELSE    
   BEGIN    
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR     
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL        
   END    
END -- Procedure     

GO