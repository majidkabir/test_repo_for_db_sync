SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Carton_Conv_Routing_Label_rdt                       */
/* Creation Date: 14-APR-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-1614 - bebe HK CPI - Conveyor Routing Label RDT Spooler */
/*        :                                                             */
/* Called By: r_dw_Carton_Conveyor_Routing_Label_rdt                    */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_Carton_Conv_Routing_Label_rdt] 
            @c_dropid         NVARCHAR(20) 
         ,  @c_Storerkey      NVARCHAR(20)      
         ,  @b_Debug          INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @n_RS              INT
         , @c_CVRRoute        NVARCHAR(10)
         , @c_UDF01           NVARCHAR(60)
         , @c_UDF02           NVARCHAR(60)
         , @c_ZoneLong        NVARCHAR(5)

         , @c_SQLInsert       NVARCHAR(4000)
         , @c_SQLSELECT       NVARCHAR(4000)
         , @c_SQLJOIN         NVARCHAR(4000)
         , @c_SQL             NVARCHAR(4000)
         , @c_Conditions      NVARCHAR(4000)
         , @c_SQLGROUPBY      NVARCHAR(4000)

DECLARE @c_ZoneS1   NVARCHAR(20),
        @c_ZoneS2   NVARCHAR(20),
        @c_ZoneS3   NVARCHAR(20),
        @c_ZoneB1   NVARCHAR(30),
        @c_ZoneB2   NVARCHAR(30),
        @c_ZoneB3   NVARCHAR(30),
        @n_Pqty     INT,
        @n_lliqty   INT,
        @c_PqtyZ1   NVARCHAR(10),
        @c_PqtyZ2   NVARCHAR(10),
        @c_PqtyZ3   NVARCHAR(10),
        @c_Wavekey  NVARCHAR(20)



         CREATE TABLE #TEMPCONROUTLBL 
         (  WAVEKEY       NVARCHAR(20) NULL,
            ZoneStation1   NVARCHAR(20) NULL,
            ZoneStation2   NVARCHAR(20) NULL,
            ZoneStation3   NVARCHAR(20) NULL,
            ZoneBarcode1   NVARCHAR(30) NULL,
            ZoneBarcode2   NVARCHAR(30) NULL,
            ZoneBarcode3   NVARCHAR(30) NULL,
            PQtyZ1         NVARCHAR(10) NULL,
            PQtyZ2         NVARCHAR(10) NULL,
            PQtyZ3         NVARCHAR(10) NULL  
            )

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1


   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END 

   SET @c_CVRRoute = ''
   SET @c_ZoneS1 = ''
   SET @c_ZoneS2 = ''
   SET @c_ZoneS3 = ''
   SET @c_ZoneB1 = ''
   SET @c_ZoneB2 = ''
   SET @c_ZoneB3 = ''
   SET @c_Wavekey = ''
   SET @c_PqtyZ1 = ''
   SET @c_PqtyZ2 = ''
   SET @c_PqtyZ3= ''
   
   DECLARE CUR_CLKUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ISNULL(RTRIM(Notes), '')
         ,UDF01 = ISNULL(RTRIM(UDF01),'')
         ,UDF02 = ISNULL(RTRIM(UDF02),'')
         ,ZoneLong = ISNULL(RTRIM(long),'')
   FROM   CODELKUP WITH (NOLOCK)
   WHERE  ListName = 'CVRRoute'
   AND    Storerkey= @c_Storerkey
   AND    Short    = 'ROUTE'
   ORDER BY long
   
   OPEN CUR_CLKUP
   
   FETCH NEXT FROM CUR_CLKUP INTO @c_Conditions, @c_UDF01,@c_UDF02,@c_ZoneLong
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      
      
      --SET @c_SQLInsert = N' INSERT INTO #TEMPCONROUTLBL (WAVEKEY,ZoneStation,ZoneBarcode,ZoneLong,PQty)'
      
      SET @n_Pqty = 0
      SET @n_lliqty = 0
      --IF @c_ZoneLong IN ('1','2')
     -- BEGIN
            SET @c_SQLSELECT = N'SELECT DISTINCT @c_Wavekey = rdtptlstationlog.wavekey'
                                + ',@n_Pqty= SUM(PICKDETAIL.qty)'
                                + ',@n_lliqty = (lli.qty-lli.qtyallocated-lli.qtypicked) '
                                + ' FROM PICKDETAIL WITH (NOLOCK)'
                                + ' LEFT JOIN RDT.rdtptlstationlog WITH (NOLOCK) ON rdtptlstationlog.orderkey = PICKDETAIL.Orderkey'
                                + ' JOIN lotxlocxid lli (NOLOCK) ON lli.Lot = pickdetail.lot AND lli.loc=pickdetail.loc AND lli.id=pickdetail.id'
                                + ' WHERE PICKDETAIL.DROPID = ''' + @c_dropid + ''''
                                +  'AND PICKDETAIL.Storerkey = ''' + @c_Storerkey + ''' '

      IF @c_Conditions <> ''
      BEGIN
         SET @c_SQLJOIN = @c_SQLSELECT + ' AND ' + @c_Conditions 
      END
      ELSE
      BEGIN
         SET @c_SQLJOIN = @c_SQLSELECT
      END   
      
      SET @c_SQLGROUPBY = 'GROUP BY rdtptlstationlog.wavekey,(lli.qty-lli.qtyallocated-lli.qtypicked)  '

      SET @c_SQL = @c_SQLInsert + CHAR(13) + @c_SQLJOIN  + CHAR(13)  + @c_SQLGROUPBY

      EXECUTE sp_ExecuteSql @c_SQL, N'@n_Pqty INT OUTPUT,@c_Wavekey NVARCHAR(20) OUTPUT,@n_lliqty INT OUTPUT', @n_Pqty OUTPUT,@c_Wavekey OUTPUT,@n_lliqty OUTPUT

      --SET @c_CVRRoute = @c_UDF01
      
      IF @b_Debug='1'
      BEGIN
         
         PRINT @c_SQL
         SELECT @c_ZoneLong AS '@c_ZoneLong',@n_Pqty AS '@n_Pqty',@c_Conditions AS '@c_Conditions '
         
      END
  -- IF @n_Pqty > 0
  -- BEGIN
      IF @c_ZoneLong = '1'
      BEGIN
          IF @n_Pqty > 0
          BEGIN
            SET @c_ZoneS1 = @c_UDF02
            SET @c_ZoneB1 = @c_UDF01
            SET @c_PqtyZ1 = CONVERT(NVARCHAR(10),@n_Pqty)
          END  
      END
      ELSE IF @c_ZoneLong = '2' 
      BEGIN
         IF @n_Pqty > 0
         BEGIN
           SET @c_ZoneS2 = @c_UDF02
           SET @c_ZoneB2 = @c_UDF01
           SET @c_PqtyZ2 = CONVERT(NVARCHAR(10),@n_Pqty)
         END  
      END
      ELSE IF @c_ZoneLong = '3' 
      BEGIN
         IF @n_lliqty > 0
         BEGIN
            SET @c_ZoneS3 = @c_UDF02
            SET @c_ZoneB3 = @c_UDF01
            SET @c_PqtyZ3 = CONVERT(NVARCHAR(10),@n_lliqty)
         END   
      END
     --END 
     --ELSE
     --BEGIN
      
     --   SET @c_PqtyZ1 = ''
     --  SET @c_PqtyZ2 = ''
     --  SET @c_PqtyZ3= ''
      
     --END  
    FETCH NEXT FROM CUR_CLKUP INTO @c_Conditions, @c_UDF01,@c_UDF02,@c_ZoneLong
   END
   CLOSE CUR_CLKUP
   DEALLOCATE CUR_CLKUP 
   
   INSERT INTO #TEMPCONROUTLBL 
         (  WAVEKEY       ,
            ZoneStation1  ,
            ZoneStation2  ,
            ZoneStation3  ,
            ZoneBarcode1  ,
            ZoneBarcode2  ,
            ZoneBarcode3  ,
            PQtyZ1        ,
            PQtyZ2        ,
            PQtyZ3          
         )
   VALUES (@c_Wavekey,@c_ZoneS1,@c_ZoneS2,@c_ZoneS3,@c_ZoneB1,@c_ZoneB2,@c_ZoneB3,@c_PqtyZ1,
          @c_PqtyZ2,@c_PqtyZ3)     
   
   SELECT * FROM #TEMPCONROUTLBL
   ORDER BY Wavekey

QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_CLKUP') in (0 , 1)  
   BEGIN
      CLOSE CUR_CLKUP
      DEALLOCATE CUR_CLKUP
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END 
END -- procedure

GO