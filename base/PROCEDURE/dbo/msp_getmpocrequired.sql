SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Procedure: msp_GetMPOCRequired                                       */
/* Creation Date: 28-May-2024                                           */
/* Copyright: Maersk Logistics                                          */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: UWP-18747 - Levis US MPOC and Cartonization                 */
/*        :                                                             */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 28-May-2024 Shong    1.1   Create                                    */
/************************************************************************/
CREATE   PROC msp_GetMPOCRequired
(
    @c_OrderKey NVARCHAR(10),
    @n_MPOCFlag   INT = 0 OUTPUT,
    @b_Success INT = 1 OUTPUT,
    @n_Err INT = 0 OUTPUT,
    @c_ErrMsg NVARCHAR(255) = '' OUTPUT,
    @b_debug INT = 0
)
AS
BEGIN
	DECLARE @n_RowCount   INT = 0, 
           @c_SQL        NVARCHAR(4000) = N'',
           @c_SQLWhere   NVARCHAR(4000) = N'',
           @c_SQLCond    NVARCHAR(4000) = N'',
           @c_StorerKey  NVARCHAR(15) = N'',
           @c_KeyValue   NVARCHAR(30) = N'', 
           @c_Operator   NVARCHAR(10) = N'', 
           @b_CheckFlag  BIT = 0,
           @n_Counts     INT = 0,
           @c_ColumnName NVARCHAR(60) = N''; 

   SELECT @c_StorerKey = StorerKey
   FROM ORDERS WITH (NOLOCK)
   WHERE OrderKey = @c_OrderKey;

   SET @c_SQLWhere = ''  

   IF EXISTS(SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)
	   WHERE LISTNAME = 'MPOCEXCEMP'   
	   AND Storerkey = @c_StorerKey )
   BEGIN
      DECLARE CUR_MPOCEXCEMP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT C.UDF02, C.Short, COUNT(1) AS [RowCount], MAX(Code) AS KeyValue
      FROM dbo.CODELKUP C WITH (NOLOCK)
      WHERE LISTNAME = 'MPOCEXCEMP'   
      AND Storerkey = @c_StorerKey 
      GROUP BY C.Short, C.UDF02
      --ORDER BY [RowCount] 

      OPEN CUR_MPOCEXCEMP;
      FETCH NEXT FROM CUR_MPOCEXCEMP INTO @c_ColumnName, @c_Operator, @n_Counts, @c_KeyValue; 
      WHILE @@FETCH_STATUS <> -1
      BEGIN 
         SET @c_SQLCond = ''
         IF @n_Counts > 1
         BEGIN
            DECLARE CUR_IN_SELECT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT Code
            FROM dbo.CODELKUP C WITH (NOLOCK)
            WHERE LISTNAME = 'MPOCEXCEMP'   
            AND Storerkey = @c_StorerKey 
            AND C.Short = @c_Operator 
            AND C.UDF02 = @c_ColumnName 

            OPEN CUR_IN_SELECT
         
            FETCH NEXT FROM CUR_IN_SELECT INTO @c_KeyValue
         
            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @c_SQLCond = ''  
                BEGIN
                   SET @c_SQLCond = @c_SQLCond + @c_ColumnName + ' IN (''' + @c_KeyValue + ''''
                END
                ELSE
                BEGIN
                    SET @c_SQLCond = @c_SQLCond + ',''' + @c_KeyValue + ''''
                END

                FETCH NEXT FROM CUR_IN_SELECT INTO @c_KeyValue
            END         
            CLOSE CUR_IN_SELECT
            DEALLOCATE CUR_IN_SELECT
            SET @c_SQLCond = @c_SQLCond + ')'
         END 
         ELSE 
         BEGIN
            IF @c_SQLCond = ''  
            BEGIN
                SET @c_SQLCond = @c_SQLCond + @c_ColumnName + ' ' + @c_Operator + '''' + @c_KeyValue + ''''
            END
            ELSE 
            BEGIN
                SET @c_SQLCond = @c_SQLCond + ' OR ' + @c_ColumnName + ' ' + @c_Operator + '''' + @c_KeyValue + ''''
            END
         END 

         --IF @b_debug = 1
         --   PRINT 'COND >>' + @c_SQLCond

         IF @c_SQLWhere = ''
         BEGIN
            SET @c_SQLWhere = 'AND (' + @c_SQLCond
         END 
         ELSE 
         BEGIN
             SET @c_SQLWhere = @c_SQLWhere + ' OR ' + @c_SQLCond
         END

         FETCH NEXT FROM CUR_MPOCEXCEMP INTO @c_ColumnName, @c_Operator, @n_Counts, @c_KeyValue; 
      END;
      CLOSE CUR_MPOCEXCEMP;
      DEALLOCATE CUR_MPOCEXCEMP; 

      SET @c_SQLWhere = @c_SQLWhere + ')'

      SET @c_SQL = N'SELECT @n_Count = COUNT(1) 
      FROM dbo.ORDERS WITH (NOLOCK)
      WHERE OrderKey = @c_OrderKey ' + @c_SQLWhere;

      --IF @b_Debug=1
      --   PRINT @c_SQL
      BEGIN TRY
         EXEC sp_executesql @c_SQL, N'@c_OrderKey NVARCHAR(10), @n_Count INT OUTPUT', @c_OrderKey, @n_RowCount OUTPUT; 
          
      END TRY
      BEGIN CATCH
         SET @b_Success = 0
         SET @n_Err = 82051
         SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': ' + 'Error Executing SQL: '  +  @c_SQL + '.(msp_GetMPOCRequired)'
      END CATCH

      IF @n_RowCount > 0
      BEGIN
         SET @n_MPOCFlag = 0;
         SET @b_CheckFlag =1
      END;        
   END



   IF @b_CheckFlag =0
   BEGIN      
      IF EXISTS(SELECT 1 FROM ORDERS AS O WITH (NOLOCK)
                JOIN dbo.ORDERDETAIL AS OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
                JOIN dbo.SKU AS S WITH (NOLOCK) ON S.StorerKey = OD.StorerKey AND S.SKU = OD.Sku
                WHERE O.OrderKey = @c_OrderKey
                AND (( S.Size IS NULL OR S.Size = '' ) 
                       OR ( S.Measurement IS NULL OR S.Measurement = '' )
                       OR ( S.PrepackIndicator IS NOT NULL AND S.PrepackIndicator <> ''))
                )
      BEGIN 
         SET @n_MPOCFlag = 0; 
      END;
      ELSE
      BEGIN
         SET @n_MPOCFlag = 0;

         SELECT @n_MPOCFlag = 
                 CASE 
                   WHEN C.Short = '0' THEN 0 -- NO MPOC NEEDED
                   WHEN C.Short = '1' THEN 1 -- JCP MPOC Formula needed
                   WHEN C.Short = '2' THEN 2 -- MACY MPOC Formula needed
                   WHEN C.Short = '3' THEN 3 -- WALMART MPOC Formula needed
                   ELSE 1 
                END
          FROM dbo.ORDERS AS O WITH (NOLOCK)
          JOIN dbo.CODELKUP AS C WITH (NOLOCK) ON LISTNAME = 'MPOC_PERMITTED'
                             AND ( C.Code = O.BillToKey OR C.Code = O.ConsigneeKey )
                             AND C.Storerkey = O.StorerKey
          WHERE O.OrderKey = @c_OrderKey;
      END; 
   END; 
   Quit_SP: 

   --IF @b_debug=1
   --   PRINT '@n_MPOCFlag= '+  CAST(@n_MPOCFlag AS VARCHAR(10))
END;

GO