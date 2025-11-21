SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: isp_ConsolidatePickdetail                          */    
/* Creation Date: 26-OCT-2017                                           */    
/* Copyright: LFL                                                       */    
/* Written by: NJOW                                                     */    
/*                                                                      */    
/* Purpose: WMS-3290 Consolidate pickdetail to full pallet/carton and   */
/*          indicate the carton is consolidate multiple order/consignee */
/*          or single                                                   */
/*          pickmethod 'C' = conso plt/carton with multiple order/cons  */
/*          Exclude pick location                                       */
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
/* Date         Author    Ver.  Purposes                                */
/* 09-Jun-2021  NJOW01    1.0   WMS-14759 Join to wave table            */
/* 12-Jan-2023  NJOW02    1.1   WMS-19078 Identify conso carton by UCC# */ 
/************************************************************************/    
CREATE   PROC [dbo].[isp_ConsolidatePickdetail]        
    @c_Loadkey                      NVARCHAR(10) = ''
  , @c_Wavekey                      NVARCHAR(10) = ''
  , @c_UOM                          NVARCHAR(10) = '2'  --UOM to Consolidate 1=Pallet  2=Carton 
  , @c_GroupFieldList               NVARCHAR(2000) = 'ORDERS.Orderkey'  --field to determine the full pallet/carton is single order/consignee. e.g. ORDERS.Consigneekey,ORDERS.Userdefine03
  , @c_ConsoGroupFieldList          NVARCHAR(2000) = 'ORDERS.Storerkey'  --field to determine the grouping of conso pallet/carton. e.g. ORDERS.ECOM_SINGLE_Flag,ORDERS.Userdefine01
  , @c_SQLCondition                 NVARCHAR(2000) = 'SKUXLOC.LocationType NOT IN (''CASE'',''PICK'') AND LOC.LocationType NOT IN(''PICK'',''DYNPPICK'',''DYNPICKP'')' --Additional condition to filter e.g. LOC.LocationType = 'BULK' AND LOC.LocationHandling = '1'
  , @c_CaseCntByUCC                 NVARCHAR(10) = 'N' --Get casecnt by ucc qty of the location. all UCC of the sku mush have same qty at the location.
  , @c_PickMethodOfConso            NVARCHAR(1) = 'C'  --Pickmethod to indicate multiple order's conso carton/pallet
  , @c_UOMOfConso                   NVARCHAR(10) = ''  --optional to Change the UOM of conso carton(uom2)/pallet(uom1) to other UOM 
  , @c_ConsolidatePieceProcess      NVARCHAR(5) = 'N'  --N=no conlidate process Y= find loose qty and combine into canton(uom2) or pallet (uom1)
  , @c_IdentifyConsoUnitProcess     NVARCHAR(5) = 'Y'  --N=no identify conso process Y=find full carton(uom2) or pallet(uom1) that consolidate multiple orders/consignee. the consolidate criteria can set at @c_GroupFieldList.
                                                       --the consolidated unit pickmethod is set as @c_PickMethodOfConso (default 'C') and UOM is set as @c_UOMOfConso (default '2')
  , @c_ConsoUnitByUCCNo             NVARCHAR(5) = 'N'  --N=no identify conso unit by UCCNo and use casecnt instead. Y=Identify conso unit by UCCNo, it only work for UOM=2 and pickdetail.droid = UCCNo. --NJOW02                                                      
  , @b_Success                      INT           OUTPUT  
  , @n_Err                          INT           OUTPUT  
  , @c_ErrMsg                       NVARCHAR(250) OUTPUT  
AS    
BEGIN    
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF         

   DECLARE  
      @n_Continue                     INT,  
      @n_StartTCnt                    INT,
      @c_Storerkey                    NVARCHAR(15), 
      @c_Facility                     NVARCHAR(5),
      @c_Sku                          NVARCHAR(20), 
      @c_Lot                          NVARCHAR(10), 
      @c_Loc                          NVARCHAR(10), 
      @c_ID                           NVARCHAR(18), 
      @n_ConsoQty                     INT,
      @n_PickQty                      INT,
      @c_PickDetailKey                NVARCHAR(18),
      @c_NewPickDetailKey             NVARCHAR(18),      
      @c_SQL                          NVARCHAR(MAX),
      @c_SQL2                         NVARCHAR(MAX),
      @c_Field                        NVARCHAR(60),
      @c_Field01                      NVARCHAR(60),
      @c_Field02                      NVARCHAR(60),
      @c_Field03                      NVARCHAR(60),
      @c_Field04                      NVARCHAR(60),
      @c_Field05                      NVARCHAR(60),
      @c_Field06                      NVARCHAR(60),
      @c_Field07                      NVARCHAR(60),
      @c_Field08                      NVARCHAR(60),
      @c_Field09                      NVARCHAR(60),
      @c_Field10                      NVARCHAR(60),
      @c_Field01Value                 NVARCHAR(100),
      @c_Field02Value                 NVARCHAR(100),
      @c_Field03Value                 NVARCHAR(100),
      @c_Field04Value                 NVARCHAR(100),
      @c_Field05Value                 NVARCHAR(100),
      @c_Field06Value                 NVARCHAR(100),
      @c_Field07Value                 NVARCHAR(100),
      @c_Field08Value                 NVARCHAR(100),
      @c_Field09Value                 NVARCHAR(100),
      @c_Field10Value                 NVARCHAR(100),
      @n_Cnt                          INT,
      @c_SQLField                     NVARCHAR(2000),
      @c_SQLGroup                     NVARCHAR(2000),
      @c_SQLWhere                     NVARCHAR(4000),
      @c_TableName                    NVARCHAR(30),
      @c_ColumnName                   NVARCHAR(30),
      @c_ColumnType                   NVARCHAR(10),      
      @c_AllocateGetCasecntFrLottable NVARCHAR(10),
      @c_Casecntfield                 NVARCHAR(50),
      @c_UCCNo                        NVARCHAR(20)  --NJOW20
  
   SELECT @n_continue = 1, @b_Success = 1, @n_Err = 0, @c_ErrMsg = '',@n_StartTCnt = @@TRANCOUNT       
   
   --initialization
   IF @n_continue IN(1,2)
   BEGIN   	
   	  CREATE TABLE #UCC (Storerkey NVARCHAR(15),
   	                     Sku NVARCHAR(20),
   	                     Lot NVARCHAR(10),
   	                     Loc NVARCHAR(10),
   	                     ID NVARCHAR(18),
   	                     Qty INT,
   	                     UCCNo NVARCHAR(20) NULL) --NJOW02
   	                        	                        	    	  
   	  IF ISNULL(@c_UOM,'') NOT IN('1','2') 
         SET @c_UOM = '2'

      IF ISNULL(@c_PickMethodOfConso,'') = ''
         SET @c_PickMethodOfConso = 'C'
      
      IF ISNULL(@c_UOMOfConso,'') = ''
         SET @c_UOMOfConso = @c_UOM
            
      IF ISNULL(@c_SQLCondition,'') = ''
         SET @c_SQLCondition = 'AND SKUXLOC.LocationType NOT IN (''CASE'',''PICK'') AND LOC.LocationType NOT IN(''PICK'',''DYNPPICK'',''DYNPICKP'')'     
      ELSE
         SET @c_SQLCondition = 'AND ' + @c_SQLCondition   
         
      IF ISNULL(@c_GroupFieldlist,'') =''
         SET @c_GroupFieldList = 'ORDERS.Orderkey'   

      IF ISNULL(@c_ConsoGroupFieldList,'') =''
         SET @c_ConsoGroupFieldList = 'ORDERS.Storerkey'            

      IF ISNULL(@c_IdentifyConsoUnitProcess,'') =''
         SET @c_IdentifyConsoUnitProcess = 'Y'                  
      
      IF ISNULL(@c_Loadkey,'') <> '' 
      BEGIN      
         SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey,
                      @c_Facility = ORDERS.Facility
         FROM ORDERS (NOLOCK)   
         JOIN LOADPLANDETAIL (NOLOCK) ON ORDERS.Orderkey = LOADPLANDETAIL.Orderkey
         WHERE LOADPLANDETAIL.LoadKey = @c_Loadkey
      END
      
      IF ISNULL(@c_Wavekey,'') <> '' AND ISNULL(@c_Storerkey,'') = ''
      BEGIN
         SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey,
                      @c_Facility = ORDERS.Facility
         FROM ORDERS (NOLOCK)   
         JOIN WAVEDETAIL (NOLOCK) ON ORDERS.Orderkey = WAVEDETAIL.Orderkey
         WHERE WAVEDETAIL.Wavekey = @c_Wavekey
      END
            
      EXECUTE nspGetRight 
         @c_facility,  -- facility
         @c_StorerKey,   -- StorerKey
         NULL,            -- Sku
         'AllocateGetCasecntFrLottable',  -- Configkey
         @b_success    OUTPUT,
         @c_AllocateGetCasecntFrLottable OUTPUT,
         @n_Err        OUTPUT,
         @c_Errmsg     OUTPUT
         
         IF @b_Success <> 1
         BEGIN
            SELECT @n_continue = 3
         END                   
         
      SELECT @c_CaseCntField = CASE WHEN @c_AllocateGetCasecntFrLottable = '01' THEN
                                       'LOTATTRIBUTE.Lottable01'
                                    WHEN @c_AllocateGetCasecntFrLottable = '02' THEN                                       
                                       'LOTATTRIBUTE.Lottable02'
                                    WHEN @c_AllocateGetCasecntFrLottable = '03' THEN                                       
                                       'LOTATTRIBUTE.Lottable03'
                                    WHEN @c_AllocateGetCasecntFrLottable = '06' THEN                                       
                                       'LOTATTRIBUTE.Lottable06'
                                    WHEN @c_AllocateGetCasecntFrLottable = '07' THEN                                       
                                       'LOTATTRIBUTE.Lottable07'
                                    WHEN @c_AllocateGetCasecntFrLottable = '08' THEN                                       
                                       'LOTATTRIBUTE.Lottable08'
                                    WHEN @c_AllocateGetCasecntFrLottable = '09' THEN                                       
                                       'LOTATTRIBUTE.Lottable09'
                                    WHEN @c_AllocateGetCasecntFrLottable = '10' THEN                                       
                                       'LOTATTRIBUTE.Lottable10'
                                    WHEN @c_AllocateGetCasecntFrLottable = '11' THEN                                       
                                       'LOTATTRIBUTE.Lottable11'
                                    WHEN @c_AllocateGetCasecntFrLottable = '12' THEN                                       
                                       'LOTATTRIBUTE.Lottable12'
                                    WHEN @c_CaseCntByUCC = 'Y' THEN
                                       'ISNULL(UCC.Qty,0)'   
                                    ELSE
                                       'PACK.CaseCnt'
                                END                                     
   END
   
   IF @n_continue IN (1,2) AND @c_CaseCntByUCC = 'Y' 
   BEGIN
   	  INSERT INTO #UCC (Storerkey, Sku, Lot, Loc, ID, Qty)  --NJOW02
   	  SELECT PICKDETAIL.Storerkey, PICKDETAIL.Sku, PICKDETAIL.Lot, PICKDETAIL.Loc, PICKDETAIL.ID, MAX(UCC.Qty) AS Qty
   	  FROM ORDERS (NOLOCK) 
      JOIN PICKDETAIL (NOLOCK) ON ORDERS.Orderkey = PICKDETAIL.Orderkey
      JOIN UCC (NOLOCK) ON  PICKDETAIL.Storerkey = UCC.Storerkey AND PICKDETAIL.Sku = UCC.SKU 
                            AND PICKDETAIL.Lot = UCC.Lot AND PICKDETAIL.Loc = UCC.Loc AND PICKDETAIL.Id = UCC.Id  
      WHERE (ORDERS.Loadkey = @c_Loadkey OR ISNULL(@c_Loadkey,'') = '')
      AND (ORDERS.Userdefine09 = @c_Wavekey OR ISNULL(@c_Wavekey,'') = '') 
      AND PICKDETAIL.UOM IN('2','6','7') 
      AND UCC.Status <= '3'
      GROUP BY PICKDETAIL.Storerkey, PICKDETAIL.Sku, PICKDETAIL.Lot, PICKDETAIL.Loc, PICKDETAIL.ID
   END                                                                                          
  
   --find out loose qty(uom 6,7) can consolidate into full pallet/carton from bulk to split and update to uom 1 or 2
   IF @n_continue IN (1,2) AND @c_ConsolidatePieceProcess = 'Y'
   BEGIN     	  
   	  SET @n_cnt = 0
   	  SET @c_SQLField = ''   	     	  
   	  --Extract conso group field list to varaiable and validation
   	  WHILE @n_cnt < 10
   	  BEGIN
     	   SELECT TOP 1 @c_Field = ColValue, 
     	                @n_cnt = SeqNo 
   	     FROM dbo.fnc_DelimSplit(',',@c_ConsoGroupFieldList)
   	     WHERE SeqNo > @n_Cnt
   	     ORDER BY Seqno
   	        	        	     
   	     IF @@ROWCOUNT = 0
   	        BREAK
   	     
   	     SET @c_TableName = LEFT(@c_Field, CharIndex('.', @c_Field) - 1)
         SET @c_ColumnName = SUBSTRING(@c_Field,
                            CharIndex('.', @c_Field) + 1, LEN(@c_Field) - CharIndex('.', @c_Field))

         IF ISNULL(RTRIM(@c_TableName), '') <> 'ORDERS'
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63510
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Conso Grouping Field Only Allow Refer To Orders Table's Fields. Invalid Table: "+RTRIM(@c_Field)+" (isp_ConsolidatePickdetail)"
            GOTO RETURN_SP
         END
         
         SET @c_ColumnType = ''
         SELECT @c_ColumnType = DATA_TYPE
         FROM   INFORMATION_SCHEMA.COLUMNS
         WHERE  TABLE_NAME = @c_TableName
         AND    COLUMN_NAME = @c_ColumnName
         
         IF ISNULL(RTRIM(@c_ColumnType), '') = ''
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63520
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid Column Name: " + RTRIM(@c_Field)+ ". (isp_ConsolidatePickdetail)"
            GOTO RETURN_SP
         END
         
         IF @c_ColumnType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint','text','datetime')
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63530
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Numeric/Text/Datetime Column Type Is Not Allowed For Conso Grouping: " + RTRIM(@c_Field)+ ". (isp_ConsolidatePickdetail)"
            GOTO RETURN_SP
         END
   	     
   	     IF @n_Cnt = 1
   	        SET @c_Field01 = @c_Field
   	     IF @n_Cnt = 2
   	        SET @c_Field02 = @c_Field
   	     IF @n_Cnt = 3
   	        SET @c_Field03 = @c_Field
   	     IF @n_Cnt = 4
   	        SET @c_Field04 = @c_Field
   	     IF @n_Cnt = 5
   	        SET @c_Field05 = @c_Field
   	     IF @n_Cnt = 6
   	        SET @c_Field06 = @c_Field
   	     IF @n_Cnt = 7
   	        SET @c_Field07 = @c_Field
   	     IF @n_Cnt = 8
   	        SET @c_Field08 = @c_Field
   	     IF @n_Cnt = 9
   	        SET @c_Field09 = @c_Field
   	     IF @n_Cnt = 10
   	        SET @c_Field10 = @c_Field   	        
   	  END
   	  
   	  --Construct select,group and where statement for conso group fields
   	  SET @n_cnt = 0
   	  SET @c_SQLWhere = ''
   	  SET @c_SQLGroup = ''   	 
   	  WHILE @n_cnt < 10                                                                     
      BEGIN                                                                                 
         SET @n_cnt = @n_cnt + 1                                                            
                                                                                          
         SELECT @c_SQLField = @c_SQLField + ', ' +                                  
            CASE WHEN @n_cnt = 1 AND ISNULL(@c_Field01,'') <> '' THEN RTRIM(@c_Field01)                         
                 WHEN @n_cnt = 2 AND ISNULL(@c_Field02,'') <> '' THEN RTRIM(@c_Field02)                                
                 WHEN @n_cnt = 3 AND ISNULL(@c_Field03,'') <> '' THEN RTRIM(@c_Field03)                                
                 WHEN @n_cnt = 4 AND ISNULL(@c_Field04,'') <> '' THEN RTRIM(@c_Field04)                                
                 WHEN @n_cnt = 5 AND ISNULL(@c_Field05,'') <> '' THEN RTRIM(@c_Field05)                                
                 WHEN @n_cnt = 6 AND ISNULL(@c_Field06,'') <> '' THEN RTRIM(@c_Field06)                                
                 WHEN @n_cnt = 7 AND ISNULL(@c_Field07,'') <> '' THEN RTRIM(@c_Field07)                                
                 WHEN @n_cnt = 8 AND ISNULL(@c_Field08,'') <> '' THEN RTRIM(@c_Field08)                                
                 WHEN @n_cnt = 9 AND ISNULL(@c_Field09,'') <> '' THEN RTRIM(@c_Field09)                                
                 WHEN @n_cnt = 10 AND ISNULL(@c_Field10,'') <> '' THEN RTRIM(@c_Field10)                                
                 ELSE ''''''
            END                

         SELECT @c_SQLGroup = @c_SQLGroup +                             
            CASE WHEN @n_cnt = 1 AND ISNULL(@c_Field01,'') <> '' THEN ', ' + RTRIM(@c_Field01)                         
                 WHEN @n_cnt = 2 AND ISNULL(@c_Field02,'') <> '' THEN ', ' + RTRIM(@c_Field02)                                
                 WHEN @n_cnt = 3 AND ISNULL(@c_Field03,'') <> '' THEN ', ' + RTRIM(@c_Field03)                                
                 WHEN @n_cnt = 4 AND ISNULL(@c_Field04,'') <> '' THEN ', ' + RTRIM(@c_Field04)                                
                 WHEN @n_cnt = 5 AND ISNULL(@c_Field05,'') <> '' THEN ', ' + RTRIM(@c_Field05)                                
                 WHEN @n_cnt = 6 AND ISNULL(@c_Field06,'') <> '' THEN ', ' + RTRIM(@c_Field06)                                
                 WHEN @n_cnt = 7 AND ISNULL(@c_Field07,'') <> '' THEN ', ' + RTRIM(@c_Field07)                                
                 WHEN @n_cnt = 8 AND ISNULL(@c_Field08,'') <> '' THEN ', ' + RTRIM(@c_Field08)                                
                 WHEN @n_cnt = 9 AND ISNULL(@c_Field09,'') <> '' THEN ', ' + RTRIM(@c_Field09)                                
                 WHEN @n_cnt = 10 AND ISNULL(@c_Field10,'') <> '' THEN ', ' + RTRIM(@c_Field10)                                
            END                
              
         SELECT @c_SQLWhere = @c_SQLWhere +                                      
            CASE WHEN @n_cnt = 1 AND ISNULL(@c_Field01,'') <> '' THEN ' AND ' + RTRIM(@c_Field01) + ' = @c_Field01Value '
                 WHEN @n_cnt = 2 AND ISNULL(@c_Field02,'') <> '' THEN ' AND ' + RTRIM(@c_Field02) + ' = @c_Field02Value '             
                 WHEN @n_cnt = 3 AND ISNULL(@c_Field03,'') <> '' THEN ' AND ' + RTRIM(@c_Field03) + ' = @c_Field03Value '             
                 WHEN @n_cnt = 4 AND ISNULL(@c_Field04,'') <> '' THEN ' AND ' + RTRIM(@c_Field04) + ' = @c_Field04Value '             
                 WHEN @n_cnt = 5 AND ISNULL(@c_Field05,'') <> '' THEN ' AND ' + RTRIM(@c_Field05) + ' = @c_Field05Value '             
                 WHEN @n_cnt = 6 AND ISNULL(@c_Field06,'') <> '' THEN ' AND ' + RTRIM(@c_Field06) + ' = @c_Field06Value '             
                 WHEN @n_cnt = 7 AND ISNULL(@c_Field07,'') <> '' THEN ' AND ' + RTRIM(@c_Field07) + ' = @c_Field07Value '             
                 WHEN @n_cnt = 8 AND ISNULL(@c_Field08,'') <> '' THEN ' AND ' + RTRIM(@c_Field08) + ' = @c_Field08Value '             
                 WHEN @n_cnt = 9 AND ISNULL(@c_Field09,'') <> '' THEN ' AND ' + RTRIM(@c_Field09) + ' = @c_Field09Value '             
                 WHEN @n_cnt = 10 AND ISNULL(@c_Field10,'') <> '' THEN ' AND ' + RTRIM(@c_Field10) + ' = @c_Field10Value '             
            END                                           
      END                                                                                   

 	    --retrieve qty of piece(uom6,7) which can consolidate into pallet/carton.
   	  SET @c_SQL = 'DECLARE CURSOR_PICKDETAILS CURSOR FAST_FORWARD READ_ONLY FOR 
                      SELECT PICKDETAIL.Storerkey, PICKDETAIL.Sku, PICKDETAIL.Lot, PICKDETAIL.Loc, PICKDETAIL.ID, ' + 
                      CASE WHEN @c_UOM = '1' THEN
                            ' FLOOR(SUM(PICKDETAIL.Qty) / CAST(PACK.Pallet AS INT)) * PACK.Pallet ' 
                           WHEN @c_UOM = '2' THEN
                            ' FLOOR(SUM(PICKDETAIL.Qty) / CAST(' + RTRIM(@c_CaseCntfield) +' AS INT)) * CAST(' + RTRIM(@c_CaseCntfield) +' AS INT) '
                      END + RTRIM(@c_SQLField) +                                                                                                        
                    ' FROM ORDERS (NOLOCK) 
                      JOIN PICKDETAIL (NOLOCK) ON ORDERS.Orderkey = PICKDETAIL.Orderkey
                      JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot 
                      JOIN SKUXLOC (NOLOCK) ON PICKDETAIL.Storerkey = SKUXLOC.Storerkey AND PICKDETAIL.Sku = SKUXLOC.Sku AND PICKDETAIL.Loc = SKUXLOC.Loc
                      JOIN LOC (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc
                      JOIN SKU (NOLOCK) ON PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku
                      JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey ' +    
                      CASE WHEN ISNULL(@c_Wavekey,'') <> '' THEN ' JOIN WAVEDETAIL (NOLOCK) ON ORDERS.Orderkey = WAVEDETAIL.Orderkey ' ELSE ' ' END +                      
                    CASE WHEN @c_CaseCntByUCC = 'Y' THEN 
                       ' LEFT JOIN #UCC UCC ON PICKDETAIL.Storerkey = UCC.Storerkey AND PICKDETAIL.Sku = UCC.SKU AND PICKDETAIL.Lot = UCC.Lot AND PICKDETAIL.Loc = UCC.Loc AND PICKDETAIL.Id = UCC.Id '
                    ELSE '' END +
                    ' WHERE PICKDETAIL.UOM IN(''6'',''7'') ' +
                    CASE WHEN ISNULL(@c_Loadkey,'') <> '' THEN ' AND ORDERS.Loadkey = @c_Loadkey ' ELSE ' ' END +
                    CASE WHEN ISNULL(@c_Wavekey,'') <> '' THEN ' AND WAVEDETAIL.Wavekey = @c_Wavekey ' ELSE ' ' END +
                    ' AND PICKDETAIL.PickMethod <> @c_PickMethodOfConso ' +                      
                      + RTRIM(@c_SQLCondition) +                      
                      CASE WHEN @c_UOM = '1' THEN
                            ' AND PACK.Pallet > 0 ' +
                            ' GROUP BY PICKDETAIL.Storerkey, PICKDETAIL.Sku, PICKDETAIL.Lot, PICKDETAIL.Loc, PICKDETAIL.ID, PACK.Pallet ' + RTRIM(@c_SQLGroup) +
                            ' HAVING FLOOR(SUM(PICKDETAIL.Qty) / CAST(PACK.Pallet AS INT)) > 0 '
                           WHEN @c_UOM = '2' THEN
                            ' AND CAST(' + RTRIM(@c_CaseCntfield) +' AS INT) > 0 ' +
                            ' GROUP BY PICKDETAIL.Storerkey, PICKDETAIL.Sku, PICKDETAIL.Lot, PICKDETAIL.Loc, PICKDETAIL.ID, ' + RTRIM(@c_CaseCntfield) + + ' ' + RTRIM(@c_SQLGroup) +                         
                            ' HAVING FLOOR(SUM(PICKDETAIL.Qty) / CAST('+ RTRIM(@c_CaseCntfield) + ' AS INT)) > 0 '
                      END      
                    
   	  EXEC sp_executesql @c_SQL,
         N'@c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10), @c_PickMethodOfConso NVARCHAR(10)',
         @c_Loadkey,
         @c_Wavekey,
         @c_PickMethodOfConso
   	             
      OPEN CURSOR_PICKDETAILS
      
      FETCH NEXT FROM CURSOR_PICKDETAILS INTO @c_Storerkey, @c_Sku, @c_Lot, @c_Loc, @c_Id, @n_ConsoQty,
                                              @c_Field01Value, @c_Field02Value, @c_Field03Value, @c_Field04Value, @c_Field05Value,
                                              @c_Field06Value, @c_Field07Value, @c_Field08Value, @c_Field09Value, @c_Field10Value
                                             
      WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)
      BEGIN
      	 --retrive pickdetail to split conso qty and update uom to 1 or 2
      	 SET @c_SQL2 = 'DECLARE CURSOR_PICKDETCONSO CURSOR FAST_FORWARD READ_ONLY FOR 	 
                           SELECT PICKDETAIL.Pickdetailkey, PICKDETAIL.Qty
                           FROM PICKDETAIL (NOLOCK)
                           JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot
                           JOIN ORDERS (NOLOCK) ON PICKDETAIL.Orderkey = ORDERS.Orderkey 
                           JOIN SKUXLOC (NOLOCK) ON PICKDETAIL.Storerkey = SKUXLOC.Storerkey AND PICKDETAIL.Sku = SKUXLOC.Sku AND PICKDETAIL.Loc = SKUXLOC.Loc
                           JOIN LOC (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc
                           JOIN SKU (NOLOCK) ON PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku                      
                           JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey ' +
                           CASE WHEN ISNULL(@c_Wavekey,'') <> '' THEN ' JOIN WAVEDETAIL (NOLOCK) ON ORDERS.Orderkey = WAVEDETAIL.Orderkey ' ELSE ' ' END +                                                 
                           CASE WHEN @c_CaseCntByUCC = 'Y' THEN 
                            ' LEFT JOIN #UCC UCC ON PICKDETAIL.Storerkey = UCC.Storerkey AND PICKDETAIL.Sku = UCC.SKU AND PICKDETAIL.Lot = UCC.Lot AND PICKDETAIL.Loc = UCC.Loc AND PICKDETAIL.Id = UCC.Id '
                           ELSE '' END +                           
                         ' WHERE PICKDETAIL.Storerkey = @c_Storerkey
                           AND PICKDETAIL.Sku = @c_Sku
                           AND PICKDETAIL.Lot = @c_Lot
                           AND PICKDETAIL.Loc = @c_Loc
                           AND PICKDETAIL.Id = @c_ID ' +
                           CASE WHEN ISNULL(@c_Loadkey,'') <> '' THEN ' AND ORDERS.Loadkey = @c_Loadkey ' ELSE ' ' END +
                           CASE WHEN ISNULL(@c_Wavekey,'') <> '' THEN ' AND WAVEDETAIL.Wavekey = @c_Wavekey ' ELSE ' ' END +
                         ' AND PICKDETAIL.UOM IN (''6'',''7'') 
                           AND PICKDETAIL.Pickmethod <> @c_PickMethodOfConso ' + RTRIM(@c_SQLCondition) +            
                          ' ORDER BY CASE WHEN PACK.Pallet > 0 THEN FLOOR(PICKDETAIL.Qty / PACK.Pallet) ELSE 0 END DESC, 
                                     CASE WHEN CAST(' + RTRIM(@c_CaseCntfield) + ' AS INT) > 0 THEN FLOOR(CASE WHEN PACK.Pallet > 0 THEN PICKDETAIL.Qty % CAST(PACK.Pallet AS INT) ELSE PICKDETAIL.Qty END 
                                                                           / CAST(' + RTRIM(@c_CaseCntfield) + ' AS INT)) ELSE 0 END DESC, 
                                     ORDERS.Loadkey,           
                                     CASE WHEN PACK.InnerPack > 0 THEN FLOOR(CASE WHEN CAST(' + RTRIM(@c_CaseCntfield) + ' AS INT) > 0 THEN PICKDETAIL.Qty % CAST(' + RTRIM(@c_CaseCntfield) + ' AS INT) ' +
                                                                                ' WHEN PACK.Pallet > 0 THEN PICKDETAIL.Qty % CAST(PACK.Pallet AS INT) ELSE PICKDETAIL.Qty END 
                                                                             / PACK.InnerPack) ELSE 0 END DESC, 
                                     CASE WHEN PACK.InnerPack > 0 THEN PICKDETAIL.Qty % CAST(PACK.InnerPack AS INT)
                                          WHEN CAST(' + RTRIM(@c_CaseCntfield) + ' AS INT) > 0 THEN PICKDETAIL.Qty % CAST(' + RTRIM(@c_CaseCntfield) + ' AS INT) ' +
                                        ' WHEN PACK.Pallet > 0 THEN PICKDETAIL.Qty % CAST(PACK.Pallet AS INT) ELSE PICKDETAIL.Qty END DESC,
                                     PICKDETAIL.Qty % @n_ConsoQty '  
                          
     	   EXEC sp_executesql @c_SQL2,
             N'@c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10), @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20),
               @c_Lot NVARCHAR(10), @c_Loc NVARCHAR(10), @c_ID NVARCHAR(18), @n_ConsoQty INT, @c_PickMethodOfConso NVARCHAR(10),
               @c_Field01Value NVARCHAR(100), @c_Field02Value NVARCHAR(100), @c_Field03Value NVARCHAR(100), @c_Field04Value NVARCHAR(100),
               @c_Field05Value NVARCHAR(100), @c_Field06Value NVARCHAR(100), @c_Field07Value NVARCHAR(100),
               @c_Field08Value NVARCHAR(100), @c_Field09Value NVARCHAR(100), @c_Field10Value NVARCHAR(100)',               
             @c_Loadkey,
             @c_Wavekey,
             @c_Storerkey,
             @c_Sku, 
             @c_Lot, 
             @c_Loc, 
             @c_Id,
             @n_ConsoQty,
             @c_PickMethodOfConso,
             @c_Field01Value,
             @c_Field02Value,
             @c_Field03Value,
             @c_Field04Value,
             @c_Field05Value,
             @c_Field06Value,
             @c_Field07Value,
             @c_Field08Value,
             @c_Field09Value,
             @c_Field10Value             
                                   
         OPEN CURSOR_PICKDETCONSO
       
         FETCH NEXT FROM CURSOR_PICKDETCONSO INTO @c_Pickdetailkey, @n_PickQty
         
         WHILE (@@FETCH_STATUS <> -1) AND @n_ConsoQty > 0 AND @n_continue IN(1,2)
         BEGIN
         	
         	 IF @n_ConsoQty >= @n_PickQty          
         	 BEGIN
      	        UPDATE PICKDETAIL WITH (ROWLOCK) 
      	        SET UOM = @c_UOM,
      	            Trafficcop = NULL
      	        WHERE Pickdetailkey = @c_Pickdetailkey
               
               SET @n_Err = @@ERROR
               
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 63540
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                  ': Update PickDetail Failed. (isp_ConsolidatePickdetail)'
               END
               
               SET @n_ConsoQty = @n_ConsoQty - @n_PickQty
            END
            ELSE
            BEGIN            
               EXECUTE nspg_GetKey      
                  'PICKDETAILKEY',      
                  10,      
                  @c_NewPickdetailKey OUTPUT,         
                  @b_success OUTPUT,       
                  @n_err OUTPUT,      
                  @c_errmsg OUTPUT      
             
               IF NOT @b_success = 1      
               BEGIN
                  SELECT @n_continue = 3      
               END                  
               
               INSERT INTO PICKDETAIL (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, 
                                       Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],         
                                       DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,      
                                       ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,           
                                       WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo,            
                                       TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, Channel_ID)               
                               SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,                                      
                                      Storerkey, Sku, AltSku, @c_UOM, @n_ConsoQty , @n_ConsoQty, QtyMoved, Status,       
                                      '''', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,                                                     
                                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                                      
                                      WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo,                                                               
                                      TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, Channel_ID                                                           
                               FROM PICKDETAIL (NOLOCK)                                                                                             
                               WHERE PickdetailKey = @c_PickdetailKey                     
               
               SET @n_Err = @@ERROR        
                                           
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 63550
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                  ': Insert PickDetail Failed. (isp_ConsolidatePickdetail)'
               END
               
               UPDATE PICKDETAIL WITH (ROWLOCK) 
               SET Qty =  Qty - @n_ConsoQty,
               TrafficCop = NULL,
               Editdate = getdate(),
               UOMQTY = @n_PickQty - @n_ConsoQty          
               WHERE Pickdetailkey = @c_PickdetailKey
      
               SET @n_Err = @@ERROR        
                                           
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 63560
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                  ': Update PickDetail Failed. (isp_ConsolidatePickdetail)'
               END
               
               SET @n_ConsoQty = 0                                  
            END
                  	
            FETCH NEXT FROM CURSOR_PICKDETCONSO INTO @c_Pickdetailkey, @n_PickQty
         END
         CLOSE CURSOR_PICKDETCONSO
         DEALLOCATE CURSOR_PICKDETCONSO
                     	       	  
         FETCH NEXT FROM CURSOR_PICKDETAILS INTO @c_Storerkey, @c_Sku, @c_Lot, @c_Loc, @c_Id, @n_ConsoQty,
                                                 @c_Field01Value, @c_Field02Value, @c_Field03Value, @c_Field04Value, @c_Field05Value,
                                                 @c_Field06Value, @c_Field07Value, @c_Field08Value, @c_Field09Value, @c_Field10Value
      END
      CLOSE CURSOR_PICKDETAILS
      DEALLOCATE CURSOR_PICKDETAILS
   END 
            
   --find out consolidate carton(multi orders) based on group fields from full pallet(UOM1)/carton(UOM2) allocated by load/wave conso allocation
   --update pickdetail.pickmethod to 'C' for conso   
   IF @n_continue IN (1,2) AND @c_IdentifyConsoUnitProcess = 'Y' AND @c_ConsoUnitByUCCNo <> 'Y' --NJOW02
   BEGIN    
   	  SET @n_cnt = 0
   	  SET @c_SQLField = ''   	     	  
   	  SELECT @c_Field01 = '', @c_Field02 = '', @c_Field03 = '', @c_Field04 = '', @c_Field05 = ''
   	  SELECT @c_Field06 = '', @c_Field07 = '', @c_Field08 = '', @c_Field09 = '', @c_Field10 = ''   	   
   	     	   
   	  --Extract group field list to varaiable and validation
   	  WHILE @n_cnt < 10
   	  BEGIN
     	   SELECT TOP 1 @c_Field = ColValue, 
     	                @n_cnt = SeqNo 
   	     FROM dbo.fnc_DelimSplit(',',@c_GroupFieldList)
   	     WHERE SeqNo > @n_Cnt
   	     ORDER BY Seqno
   	        	        	     
   	     IF @@ROWCOUNT = 0
   	        BREAK
   	     
   	     SET @c_TableName = LEFT(@c_Field, CharIndex('.', @c_Field) - 1)
         SET @c_ColumnName = SUBSTRING(@c_Field,
                            CharIndex('.', @c_Field) + 1, LEN(@c_Field) - CharIndex('.', @c_Field))

         IF ISNULL(RTRIM(@c_TableName), '') <> 'ORDERS'
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63570
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Grouping Field Only Allow Refer To Orders Table's Fields. Invalid Table: "+RTRIM(@c_Field)+" (isp_ConsolidatePickdetail)"
            GOTO RETURN_SP
         END
         
         SET @c_ColumnType = ''
         SELECT @c_ColumnType = DATA_TYPE
         FROM   INFORMATION_SCHEMA.COLUMNS
         WHERE  TABLE_NAME = @c_TableName
         AND    COLUMN_NAME = @c_ColumnName
         
         IF ISNULL(RTRIM(@c_ColumnType), '') = ''
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63580
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid Column Name: " + RTRIM(@c_Field)+ ". (isp_ConsolidatePickdetail)"
            GOTO RETURN_SP
         END
         
         IF @c_ColumnType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint','text','datetime')
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63590
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Numeric/Text/Datetime Column Type Is Not Allowed For Grouping: " + RTRIM(@c_Field)+ ". (isp_ConsolidatePickdetail)"
            GOTO RETURN_SP
         END
   	     
   	     IF @n_Cnt = 1
   	        SET @c_Field01 = @c_Field
   	     IF @n_Cnt = 2
   	        SET @c_Field02 = @c_Field
   	     IF @n_Cnt = 3
   	        SET @c_Field03 = @c_Field
   	     IF @n_Cnt = 4
   	        SET @c_Field04 = @c_Field
   	     IF @n_Cnt = 5
   	        SET @c_Field05 = @c_Field
   	     IF @n_Cnt = 6
   	        SET @c_Field06 = @c_Field
   	     IF @n_Cnt = 7
   	        SET @c_Field07 = @c_Field
   	     IF @n_Cnt = 8
   	        SET @c_Field08 = @c_Field
   	     IF @n_Cnt = 9
   	        SET @c_Field09 = @c_Field
   	     IF @n_Cnt = 10
   	        SET @c_Field10 = @c_Field   	        
   	  END
   	  
   	  --Construct select,group and where statement for group fields
   	  SET @n_cnt = 0
   	  SET @c_SQLWhere = ''
   	  SET @c_SQLGroup = ''   	 
   	  WHILE @n_cnt < 10                                                                     
      BEGIN                                                                                 
         SET @n_cnt = @n_cnt + 1                                                            
                                                                                          
         SELECT @c_SQLField = @c_SQLField + ', ' +                                  
            CASE WHEN @n_cnt = 1 AND ISNULL(@c_Field01,'') <> '' THEN RTRIM(@c_Field01)                         
                 WHEN @n_cnt = 2 AND ISNULL(@c_Field02,'') <> '' THEN RTRIM(@c_Field02)                                
                 WHEN @n_cnt = 3 AND ISNULL(@c_Field03,'') <> '' THEN RTRIM(@c_Field03)                                
                 WHEN @n_cnt = 4 AND ISNULL(@c_Field04,'') <> '' THEN RTRIM(@c_Field04)                                
                 WHEN @n_cnt = 5 AND ISNULL(@c_Field05,'') <> '' THEN RTRIM(@c_Field05)                                
                 WHEN @n_cnt = 6 AND ISNULL(@c_Field06,'') <> '' THEN RTRIM(@c_Field06)                                
                 WHEN @n_cnt = 7 AND ISNULL(@c_Field07,'') <> '' THEN RTRIM(@c_Field07)                                
                 WHEN @n_cnt = 8 AND ISNULL(@c_Field08,'') <> '' THEN RTRIM(@c_Field08)                                
                 WHEN @n_cnt = 9 AND ISNULL(@c_Field09,'') <> '' THEN RTRIM(@c_Field09)                                
                 WHEN @n_cnt = 10 AND ISNULL(@c_Field10,'') <> '' THEN RTRIM(@c_Field10)                                
                 ELSE ''''''
            END                

         SELECT @c_SQLGroup = @c_SQLGroup +                             
            CASE WHEN @n_cnt = 1 AND ISNULL(@c_Field01,'') <> '' THEN ', ' + RTRIM(@c_Field01)                         
                 WHEN @n_cnt = 2 AND ISNULL(@c_Field02,'') <> '' THEN ', ' + RTRIM(@c_Field02)                                
                 WHEN @n_cnt = 3 AND ISNULL(@c_Field03,'') <> '' THEN ', ' + RTRIM(@c_Field03)                                
                 WHEN @n_cnt = 4 AND ISNULL(@c_Field04,'') <> '' THEN ', ' + RTRIM(@c_Field04)                                
                 WHEN @n_cnt = 5 AND ISNULL(@c_Field05,'') <> '' THEN ', ' + RTRIM(@c_Field05)                                
                 WHEN @n_cnt = 6 AND ISNULL(@c_Field06,'') <> '' THEN ', ' + RTRIM(@c_Field06)                                
                 WHEN @n_cnt = 7 AND ISNULL(@c_Field07,'') <> '' THEN ', ' + RTRIM(@c_Field07)                                
                 WHEN @n_cnt = 8 AND ISNULL(@c_Field08,'') <> '' THEN ', ' + RTRIM(@c_Field08)                                
                 WHEN @n_cnt = 9 AND ISNULL(@c_Field09,'') <> '' THEN ', ' + RTRIM(@c_Field09)                                
                 WHEN @n_cnt = 10 AND ISNULL(@c_Field10,'') <> '' THEN ', ' + RTRIM(@c_Field10)                                
            END                
              
         SELECT @c_SQLWhere = @c_SQLWhere +                                      
            CASE WHEN @n_cnt = 1 AND ISNULL(@c_Field01,'') <> '' THEN ' AND ' + RTRIM(@c_Field01) + ' = @c_Field01Value '
                 WHEN @n_cnt = 2 AND ISNULL(@c_Field02,'') <> '' THEN ' AND ' + RTRIM(@c_Field02) + ' = @c_Field02Value '             
                 WHEN @n_cnt = 3 AND ISNULL(@c_Field03,'') <> '' THEN ' AND ' + RTRIM(@c_Field03) + ' = @c_Field03Value '             
                 WHEN @n_cnt = 4 AND ISNULL(@c_Field04,'') <> '' THEN ' AND ' + RTRIM(@c_Field04) + ' = @c_Field04Value '             
                 WHEN @n_cnt = 5 AND ISNULL(@c_Field05,'') <> '' THEN ' AND ' + RTRIM(@c_Field05) + ' = @c_Field05Value '             
                 WHEN @n_cnt = 6 AND ISNULL(@c_Field06,'') <> '' THEN ' AND ' + RTRIM(@c_Field06) + ' = @c_Field06Value '             
                 WHEN @n_cnt = 7 AND ISNULL(@c_Field07,'') <> '' THEN ' AND ' + RTRIM(@c_Field07) + ' = @c_Field07Value '             
                 WHEN @n_cnt = 8 AND ISNULL(@c_Field08,'') <> '' THEN ' AND ' + RTRIM(@c_Field08) + ' = @c_Field08Value '             
                 WHEN @n_cnt = 9 AND ISNULL(@c_Field09,'') <> '' THEN ' AND ' + RTRIM(@c_Field09) + ' = @c_Field09Value '             
                 WHEN @n_cnt = 10 AND ISNULL(@c_Field10,'') <> '' THEN ' AND ' + RTRIM(@c_Field10) + ' = @c_Field10Value '             
            END                                           
      END                                                                                   
 	  
 	    --retrieve qty of full pallet/carton which consolidate mulitple orders/<group field>
   	  SET @c_SQL = 'DECLARE CURSOR_PICKDETAILS_2 CURSOR FAST_FORWARD READ_ONLY FOR 
                      SELECT PICKDETAIL.Storerkey, PICKDETAIL.Sku, PICKDETAIL.Lot, PICKDETAIL.Loc, PICKDETAIL.ID, ' + 
                      CASE WHEN @c_UOM = '1' THEN
                            ' SUM(PICKDETAIL.Qty) % CAST(PACK.Pallet AS INT) ' 
                           WHEN @c_UOM = '2' THEN
                            ' SUM(PICKDETAIL.Qty) % CAST(' + RTRIM(@c_CaseCntfield) + ' AS INT) '
                      END + RTRIM(@c_SQLField) +                                                                                                        
                    ' FROM ORDERS (NOLOCK) 
                      JOIN PICKDETAIL (NOLOCK) ON ORDERS.Orderkey = PICKDETAIL.Orderkey
                      JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot
                      JOIN SKUXLOC (NOLOCK) ON PICKDETAIL.Storerkey = SKUXLOC.Storerkey AND PICKDETAIL.Sku = SKUXLOC.Sku AND PICKDETAIL.Loc = SKUXLOC.Loc
                      JOIN LOC (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc
                      JOIN SKU (NOLOCK) ON PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku
                      JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey ' +                     
                      CASE WHEN ISNULL(@c_Wavekey,'') <> '' THEN ' JOIN WAVEDETAIL (NOLOCK) ON ORDERS.Orderkey = WAVEDETAIL.Orderkey ' ELSE ' ' END +                      
                      CASE WHEN ISNULL(@c_Wavekey,'') <> '' THEN ' JOIN WAVE (NOLOCK) ON WAVEDETAIL.Wavekey = WAVE.Wavekey ' ELSE ' ' END +  --NJOW01                      
                    CASE WHEN @c_CaseCntByUCC = 'Y' THEN 
                       ' LEFT JOIN #UCC UCC ON PICKDETAIL.Storerkey = UCC.Storerkey AND PICKDETAIL.Sku = UCC.SKU AND PICKDETAIL.Lot = UCC.Lot AND PICKDETAIL.Loc = UCC.Loc AND PICKDETAIL.Id = UCC.Id '
                    ELSE '' END +
                    ' WHERE 1=1 ' +
                    CASE WHEN ISNULL(@c_Loadkey,'') <> '' THEN ' AND ORDERS.Loadkey = @c_Loadkey ' ELSE ' ' END +
                    CASE WHEN ISNULL(@c_Wavekey,'') <> '' THEN ' AND WAVEDETAIL.Wavekey = @c_Wavekey ' ELSE ' ' END                       
                    + RTRIM(@c_SQLCondition) +                      
                      CASE WHEN @c_UOM = '1' THEN
                            ' AND PICKDETAIL.UOM = ''1'' AND PACK.Pallet > 0 
                              GROUP BY PICKDETAIL.Storerkey, PICKDETAIL.Sku, PICKDETAIL.Lot, PICKDETAIL.Loc, PICKDETAIL.ID, PACK.Pallet ' + RTRIM(@c_SQLGroup) +
                            ' HAVING SUM(PICKDETAIL.Qty) % CAST(PACK.Pallet AS INT) <> 0 '
                           WHEN @c_UOM = '2' THEN
                            ' AND PICKDETAIL.UOM = ''2'' AND CAST(' + RTRIM(@c_CaseCntfield) + ' AS INT) > 0 
                              GROUP BY PICKDETAIL.Storerkey, PICKDETAIL.Sku, PICKDETAIL.Lot, PICKDETAIL.Loc, PICKDETAIL.ID, ' + RTRIM(@c_CaseCntfield) + ' ' + RTRIM(@c_SQLGroup) +
                            ' HAVING SUM(PICKDETAIL.Qty) % CAST(' + RTRIM(@c_CaseCntfield) + ' AS INT) <> 0 '
                      END      
                    
   	  EXEC sp_executesql @c_SQL,
         N'@c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10)',
         @c_Loadkey,
         @c_Wavekey
   	             
      OPEN CURSOR_PICKDETAILS_2
      
      FETCH NEXT FROM CURSOR_PICKDETAILS_2 INTO @c_Storerkey, @c_Sku, @c_Lot, @c_Loc, @c_Id, @n_ConsoQty, 
                                                @c_Field01Value, @c_Field02Value, @c_Field03Value, @c_Field04Value, @c_Field05Value,
                                                @c_Field06Value, @c_Field07Value, @c_Field08Value, @c_Field09Value, @c_Field10Value
                                              
      WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)
      BEGIN
      	 --retrive pickdetail to split conso qty and update pickmethod to 'C'
      	 SET @c_SQL2 = 'DECLARE CURSOR_PICKDETCONSO_2 CURSOR FAST_FORWARD READ_ONLY FOR 	 
                           SELECT PICKDETAIL.Pickdetailkey, PICKDETAIL.Qty
                           FROM PICKDETAIL (NOLOCK)
                           JOIN ORDERS (NOLOCK) ON PICKDETAIL.Orderkey = ORDERS.Orderkey 
                           JOIN SKUXLOC (NOLOCK) ON PICKDETAIL.Storerkey = SKUXLOC.Storerkey AND PICKDETAIL.Sku = SKUXLOC.Sku AND PICKDETAIL.Loc = SKUXLOC.Loc
                           JOIN LOC (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc
                           JOIN SKU (NOLOCK) ON PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku                      
                           JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey ' +
                           CASE WHEN ISNULL(@c_Wavekey,'') <> '' THEN ' JOIN WAVEDETAIL (NOLOCK) ON ORDERS.Orderkey = WAVEDETAIL.Orderkey ' ELSE ' ' END +                                                 
                           CASE WHEN ISNULL(@c_Wavekey,'') <> '' THEN ' JOIN WAVE (NOLOCK) ON WAVEDETAIL.Wavekey = WAVE.Wavekey ' ELSE ' ' END +  --NJOW01                      
                         ' WHERE PICKDETAIL.Storerkey = @c_Storerkey
                           AND PICKDETAIL.Sku = @c_Sku
                           AND PICKDETAIL.Lot = @c_Lot
                           AND PICKDETAIL.Loc = @c_Loc
                           AND PICKDETAIL.Id = @c_ID ' +
                           CASE WHEN ISNULL(@c_Loadkey,'') <> '' THEN ' AND ORDERS.Loadkey = @c_Loadkey ' ELSE ' ' END +
                           CASE WHEN ISNULL(@c_Wavekey,'') <> '' THEN ' AND WAVEDETAIL.Wavekey = @c_Wavekey ' ELSE ' ' END +                           
                         ' AND PICKDETAIL.UOM = @c_UOM ' + RTRIM(@c_SQLWhere) + ' ' + RTRIM(@c_SQLCondition) +                               
                         ' ORDER BY PICKDETAIL.Qty '
                          
     	   EXEC sp_executesql @c_SQL2,
             N'@c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10), @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20),
               @c_Lot NVARCHAR(10), @c_Loc NVARCHAR(10), @c_ID NVARCHAR(18), @c_UOM NVARCHAR(10), @c_Field01Value NVARCHAR(100),
               @c_Field02Value NVARCHAR(100), @c_Field03Value NVARCHAR(100), @c_Field04Value NVARCHAR(100),
               @c_Field05Value NVARCHAR(100), @c_Field06Value NVARCHAR(100), @c_Field07Value NVARCHAR(100),
               @c_Field08Value NVARCHAR(100), @c_Field09Value NVARCHAR(100), @c_Field10Value NVARCHAR(100)',
             @c_Loadkey,
             @c_Wavekey,
             @c_Storerkey,
             @c_Sku, 
             @c_Lot, 
             @c_Loc, 
             @c_Id,
             @c_UOM,
             @c_Field01Value,
             @c_Field02Value,
             @c_Field03Value,
             @c_Field04Value,
             @c_Field05Value,
             @c_Field06Value,
             @c_Field07Value,
             @c_Field08Value,
             @c_Field09Value,
             @c_Field10Value
                                   
         OPEN CURSOR_PICKDETCONSO_2
       
         FETCH NEXT FROM CURSOR_PICKDETCONSO_2 INTO @c_Pickdetailkey, @n_PickQty
         
         WHILE (@@FETCH_STATUS <> -1) AND @n_ConsoQty > 0 AND @n_continue IN(1,2)
         BEGIN
         	
         	 IF @n_ConsoQty >= @n_PickQty          
         	 BEGIN
      	        UPDATE PICKDETAIL WITH (ROWLOCK) 
      	        SET PickMethod = @c_PickMethodOfConso,
      	            UOM = @c_UOMOfConso,
      	            Trafficcop = NULL
      	        WHERE Pickdetailkey = @c_Pickdetailkey
               
               SET @n_Err = @@ERROR
               
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 63600
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                  ': Update PickDetail Failed. (isp_ConsolidatePickdetail)'
               END
               
               SET @n_ConsoQty = @n_ConsoQty - @n_PickQty
            END
            ELSE
            BEGIN            
               EXECUTE nspg_GetKey      
                  'PICKDETAILKEY',      
                  10,      
                  @c_NewPickdetailKey OUTPUT,         
                  @b_success OUTPUT,      
                  @n_err OUTPUT,      
                  @c_errmsg OUTPUT      
             
               IF NOT @b_success = 1      
               BEGIN
                  SELECT @n_continue = 3      
               END                  
               
               INSERT INTO PICKDETAIL (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, 
                                       Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],         
                                       DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,      
                                       ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,           
                                       WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo,            
                                       TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, Channel_ID)               
                               SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,                                      
                                      Storerkey, Sku, AltSku, @c_UOMOfConso, @n_ConsoQty , @n_ConsoQty, QtyMoved, Status,       
                                      '''', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,                                                     
                                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, @c_PickMethodOfConso,                                                      
                                      WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo,                                                               
                                      TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, Channel_ID                                                           
                               FROM PICKDETAIL (NOLOCK)                                                                                             
                               WHERE PickdetailKey = @c_PickdetailKey                     
               
               SET @n_Err = @@ERROR        
                                           
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 63610
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                  ': Insert PickDetail Failed. (isp_ConsolidatePickdetail)'
               END
               
               UPDATE PICKDETAIL WITH (ROWLOCK) 
               SET Qty =  Qty - @n_ConsoQty,
               TrafficCop = NULL,
               Editdate = getdate(),
               UOMQTY = @n_PickQty - @n_ConsoQty          
               WHERE Pickdetailkey = @c_PickdetailKey
      
               SET @n_Err = @@ERROR        
                                           
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 63620
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                  ': Update PickDetail Failed. (isp_ConsolidatePickdetail)'
               END
               
               SET @n_ConsoQty = 0                                  
            END
                  	
            FETCH NEXT FROM CURSOR_PICKDETCONSO_2 INTO @c_Pickdetailkey, @n_PickQty
         END
         CLOSE CURSOR_PICKDETCONSO_2
         DEALLOCATE CURSOR_PICKDETCONSO_2
                     	       	  
         FETCH NEXT FROM CURSOR_PICKDETAILS_2 INTO @c_Storerkey, @c_Sku, @c_Lot, @c_Loc, @c_Id, @n_ConsoQty, 
                                                   @c_Field01Value, @c_Field02Value, @c_Field03Value, @c_Field04Value, @c_Field05Value,
                                                   @c_Field06Value, @c_Field07Value, @c_Field08Value, @c_Field09Value, @c_Field10Value
      END
      CLOSE CURSOR_PICKDETAILS_2
      DEALLOCATE CURSOR_PICKDETAILS_2
   END 

   --find out consolidate carton(multi orders) based on group fields from carton(UOM2) by UCC# allocated by load/wave conso allocation
   --update pickdetail.pickmethod to 'C' for conso   
   IF @n_continue IN (1,2) AND @c_IdentifyConsoUnitProcess = 'Y' AND @c_ConsoUnitByUCCNo = 'Y' AND @c_UOM = '2'  --NJOW02
   BEGIN    
   	  SET @n_cnt = 0
   	  SET @c_SQLField = ''   	     	  
   	  SELECT @c_Field01 = '', @c_Field02 = '', @c_Field03 = '', @c_Field04 = '', @c_Field05 = ''
   	  SELECT @c_Field06 = '', @c_Field07 = '', @c_Field08 = '', @c_Field09 = '', @c_Field10 = ''   	   
   	  TRUNCATE TABLE #UCC
   	     	   
   	  --Extract group field list to varaiable and validation
   	  WHILE @n_cnt < 10
   	  BEGIN
     	   SELECT TOP 1 @c_Field = ColValue, 
     	                @n_cnt = SeqNo 
   	     FROM dbo.fnc_DelimSplit(',',@c_GroupFieldList)
   	     WHERE SeqNo > @n_Cnt
   	     ORDER BY Seqno
   	        	        	     
   	     IF @@ROWCOUNT = 0
   	        BREAK
   	     
   	     SET @c_TableName = LEFT(@c_Field, CharIndex('.', @c_Field) - 1)
         SET @c_ColumnName = SUBSTRING(@c_Field,
                            CharIndex('.', @c_Field) + 1, LEN(@c_Field) - CharIndex('.', @c_Field))

         IF ISNULL(RTRIM(@c_TableName), '') <> 'ORDERS'
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63630
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Grouping Field Only Allow Refer To Orders Table's Fields. Invalid Table: "+RTRIM(@c_Field)+" (isp_ConsolidatePickdetail)"
            GOTO RETURN_SP
         END
         
         SET @c_ColumnType = ''
         SELECT @c_ColumnType = DATA_TYPE
         FROM   INFORMATION_SCHEMA.COLUMNS
         WHERE  TABLE_NAME = @c_TableName
         AND    COLUMN_NAME = @c_ColumnName
         
         IF ISNULL(RTRIM(@c_ColumnType), '') = ''
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63640
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid Column Name: " + RTRIM(@c_Field)+ ". (isp_ConsolidatePickdetail)"
            GOTO RETURN_SP
         END
         
         IF @c_ColumnType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint','text','datetime')
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63650
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Numeric/Text/Datetime Column Type Is Not Allowed For Grouping: " + RTRIM(@c_Field)+ ". (isp_ConsolidatePickdetail)"
            GOTO RETURN_SP
         END
   	     
   	     IF @n_Cnt = 1
   	        SET @c_Field01 = @c_Field
   	     IF @n_Cnt = 2
   	        SET @c_Field02 = @c_Field
   	     IF @n_Cnt = 3
   	        SET @c_Field03 = @c_Field
   	     IF @n_Cnt = 4
   	        SET @c_Field04 = @c_Field
   	     IF @n_Cnt = 5
   	        SET @c_Field05 = @c_Field
   	     IF @n_Cnt = 6
   	        SET @c_Field06 = @c_Field
   	     IF @n_Cnt = 7
   	        SET @c_Field07 = @c_Field
   	     IF @n_Cnt = 8
   	        SET @c_Field08 = @c_Field
   	     IF @n_Cnt = 9
   	        SET @c_Field09 = @c_Field
   	     IF @n_Cnt = 10
   	        SET @c_Field10 = @c_Field   	        
   	  END
   	  
   	  --Construct select,group and where statement for group fields
   	  SET @n_cnt = 0
   	  SET @c_SQLWhere = ''
   	  SET @c_SQLGroup = ''   	 
   	  WHILE @n_cnt < 10                                                                     
      BEGIN                                                                                 
         SET @n_cnt = @n_cnt + 1                                                            
                                                                                          
         SELECT @c_SQLGroup = @c_SQLGroup +                             
            CASE WHEN @n_cnt = 1 AND ISNULL(@c_Field01,'') <> '' THEN ', ' + RTRIM(@c_Field01)                         
                 WHEN @n_cnt = 2 AND ISNULL(@c_Field02,'') <> '' THEN ', ' + RTRIM(@c_Field02)                                
                 WHEN @n_cnt = 3 AND ISNULL(@c_Field03,'') <> '' THEN ', ' + RTRIM(@c_Field03)                                
                 WHEN @n_cnt = 4 AND ISNULL(@c_Field04,'') <> '' THEN ', ' + RTRIM(@c_Field04)                                
                 WHEN @n_cnt = 5 AND ISNULL(@c_Field05,'') <> '' THEN ', ' + RTRIM(@c_Field05)                                
                 WHEN @n_cnt = 6 AND ISNULL(@c_Field06,'') <> '' THEN ', ' + RTRIM(@c_Field06)                                
                 WHEN @n_cnt = 7 AND ISNULL(@c_Field07,'') <> '' THEN ', ' + RTRIM(@c_Field07)                                
                 WHEN @n_cnt = 8 AND ISNULL(@c_Field08,'') <> '' THEN ', ' + RTRIM(@c_Field08)                                
                 WHEN @n_cnt = 9 AND ISNULL(@c_Field09,'') <> '' THEN ', ' + RTRIM(@c_Field09)                                
                 WHEN @n_cnt = 10 AND ISNULL(@c_Field10,'') <> '' THEN ', ' + RTRIM(@c_Field10)                                
            END                         
      END                                                                                   
 	  
 	    --retrieve full UCC which consolidate mulitple orders/<group field>
   	  SET @c_SQL = '  INSERT INTO #UCC (Storerkey, Sku, Lot, Loc, ID, Qty, UCCNo) 
                      SELECT PICKDETAIL.Storerkey, PICKDETAIL.Sku, PICKDETAIL.Lot, PICKDETAIL.Loc, PICKDETAIL.ID, UCC.Qty, UCC.UCCNo
                      FROM ORDERS (NOLOCK) 
                      JOIN PICKDETAIL (NOLOCK) ON ORDERS.Orderkey = PICKDETAIL.Orderkey
                      JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot
                      JOIN SKUXLOC (NOLOCK) ON PICKDETAIL.Storerkey = SKUXLOC.Storerkey AND PICKDETAIL.Sku = SKUXLOC.Sku AND PICKDETAIL.Loc = SKUXLOC.Loc
                      JOIN LOC (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc
                      JOIN SKU (NOLOCK) ON PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku
                      JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey ' +                     
                      CASE WHEN ISNULL(@c_Wavekey,'') <> '' THEN ' JOIN WAVEDETAIL (NOLOCK) ON ORDERS.Orderkey = WAVEDETAIL.Orderkey ' ELSE ' ' END +                      
                      CASE WHEN ISNULL(@c_Wavekey,'') <> '' THEN ' JOIN WAVE (NOLOCK) ON WAVEDETAIL.Wavekey = WAVE.Wavekey ' ELSE ' ' END +  --NJOW01                      
                    ' JOIN UCC (NOLOCK) ON PICKDETAIL.Storerkey = UCC.Storerkey AND PICKDETAIL.Sku = UCC.SKU AND PICKDETAIL.Lot = UCC.Lot AND PICKDETAIL.Loc = UCC.Loc AND PICKDETAIL.Id = UCC.Id AND PICKDETAIL.DropID = UCC.UCCNo ' +
                    ' WHERE 1=1 ' +
                    CASE WHEN ISNULL(@c_Loadkey,'') <> '' THEN ' AND ORDERS.Loadkey = @c_Loadkey ' ELSE ' ' END +
                    CASE WHEN ISNULL(@c_Wavekey,'') <> '' THEN ' AND WAVEDETAIL.Wavekey = @c_Wavekey ' ELSE ' ' END                       
                    + RTRIM(@c_SQLCondition) +                      
                    ' AND PICKDETAIL.UOM = ''2'' 
                      GROUP BY PICKDETAIL.Storerkey, PICKDETAIL.Sku, PICKDETAIL.Lot, PICKDETAIL.Loc, PICKDETAIL.ID, UCC.UCCNo, UCC.Qty ' + RTRIM(@c_SQLGroup) +
                            ' HAVING SUM(PICKDETAIL.Qty) % UCC.Qty <> 0 '
                    
   	  EXEC sp_executesql @c_SQL,
         N'@c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10)',
         @c_Loadkey,
         @c_Wavekey
         
      DECLARE CURSOR_CONSOUCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT DISTINCT Storerkey, Sku, Lot, Loc, ID, UCCNo
         FROM #UCC
         ORDER BY Sku, UCCNo
                               	             
      OPEN CURSOR_CONSOUCC
      
      FETCH NEXT FROM CURSOR_CONSOUCC INTO @c_Storerkey, @c_Sku, @c_Lot, @c_Loc, @c_Id, @c_UCCNo
                                              
      WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)
      BEGIN
      	 --retrive pickdetail by UCC to update pickmethod to 'C'
      	 SET @c_SQL2 = 'DECLARE CURSOR_PICKDETCONSO_3 CURSOR FAST_FORWARD READ_ONLY FOR 	 
                           SELECT PICKDETAIL.Pickdetailkey
                           FROM PICKDETAIL (NOLOCK)
                           JOIN ORDERS (NOLOCK) ON PICKDETAIL.Orderkey = ORDERS.Orderkey 
                           JOIN SKUXLOC (NOLOCK) ON PICKDETAIL.Storerkey = SKUXLOC.Storerkey AND PICKDETAIL.Sku = SKUXLOC.Sku AND PICKDETAIL.Loc = SKUXLOC.Loc
                           JOIN LOC (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc
                           JOIN SKU (NOLOCK) ON PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku                      
                           JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey ' +
                           CASE WHEN ISNULL(@c_Wavekey,'') <> '' THEN ' JOIN WAVEDETAIL (NOLOCK) ON ORDERS.Orderkey = WAVEDETAIL.Orderkey ' ELSE ' ' END +                                                 
                           CASE WHEN ISNULL(@c_Wavekey,'') <> '' THEN ' JOIN WAVE (NOLOCK) ON WAVEDETAIL.Wavekey = WAVE.Wavekey ' ELSE ' ' END +  --NJOW01                      
                         ' WHERE PICKDETAIL.Storerkey = @c_Storerkey
                           AND PICKDETAIL.Sku = @c_Sku
                           AND PICKDETAIL.Lot = @c_Lot
                           AND PICKDETAIL.Loc = @c_Loc
                           AND PICKDETAIL.Id = @c_ID ' +
                           CASE WHEN ISNULL(@c_Loadkey,'') <> '' THEN ' AND ORDERS.Loadkey = @c_Loadkey ' ELSE ' ' END +
                           CASE WHEN ISNULL(@c_Wavekey,'') <> '' THEN ' AND WAVEDETAIL.Wavekey = @c_Wavekey ' ELSE ' ' END +                           
                         ' AND PICKDETAIL.UOM = ''2'' 
                           AND PICKDETAIL.DropID = @c_UCCNo ' + RTRIM(@c_SQLCondition) +                               
                         ' ORDER BY PICKDETAIL.PickdetailKey '
                          
     	   EXEC sp_executesql @c_SQL2,
             N'@c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10), @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20),
               @c_Lot NVARCHAR(10), @c_Loc NVARCHAR(10), @c_ID NVARCHAR(18), @c_UCCNo NVARCHAR(20)',
             @c_Loadkey,
             @c_Wavekey,
             @c_Storerkey,
             @c_Sku, 
             @c_Lot, 
             @c_Loc, 
             @c_Id,
             @c_UCCNo
                                   
         OPEN CURSOR_PICKDETCONSO_3
       
         FETCH NEXT FROM CURSOR_PICKDETCONSO_3 INTO @c_Pickdetailkey
         
         WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)
         BEGIN         	
      	    UPDATE PICKDETAIL WITH (ROWLOCK) 
      	    SET PickMethod = @c_PickMethodOfConso,
      	        UOM = @c_UOMOfConso,
      	        Trafficcop = NULL
      	    WHERE Pickdetailkey = @c_Pickdetailkey
            
            SET @n_Err = @@ERROR
            
            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 63660
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                               ': Update PickDetail Failed. (isp_ConsolidatePickdetail)'
            END
                  	
            FETCH NEXT FROM CURSOR_PICKDETCONSO_3 INTO @c_Pickdetailkey
         END
         CLOSE CURSOR_PICKDETCONSO_3
         DEALLOCATE CURSOR_PICKDETCONSO_3
                     	       	  
         FETCH NEXT FROM CURSOR_CONSOUCC INTO @c_Storerkey, @c_Sku, @c_Lot, @c_Loc, @c_Id, @c_UCCNo
      END
      CLOSE CURSOR_CONSOUCC
      DEALLOCATE CURSOR_CONSOUCC
   END 
      
RETURN_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_Success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_ConsolidatePickdetail'  
  		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  
END -- Procedure

GO