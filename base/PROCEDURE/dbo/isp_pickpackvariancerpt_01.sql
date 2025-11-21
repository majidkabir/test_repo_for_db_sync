SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_PickPackVarianceRpt_01                         */
/* Creation Date: 01-Oct-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  SOS#290455: VFCDC- Pick & Packing Variance                 */
/*                                                                      */
/* Input Parameters: @c_Wavekey, @c_ExternOrderkey, @c_DropID, @c_Sku   */
/*                                                                      */
/* Called By:  dw = r_dw_pickpack_discrepancy_01                        */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/
CREATE PROC [dbo].[isp_PickPackVarianceRpt_01] (
      @c_WaveFrom          NVARCHAR(10) 
   ,  @c_WaveTo            NVARCHAR(10) 
   ,  @c_ExternOrderFrom   NVARCHAR(30)
   ,  @c_ExternOrderTo     NVARCHAR(30)
   ,  @c_DropIDFrom        NVARCHAR(20)
   ,  @c_DropIDTo          NVARCHAR(20)
   ,  @c_SkuFrom           NVARCHAR(20)
   ,  @c_SkuTo             NVARCHAR(20)
) 
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt    INT
         , @n_Qty          INT
         , @n_QtyPicked    INT
         , @n_QtyPacked    INT
         , @n_QtyRDTPacked INT

         , @c_Wavekey         NVARCHAR(10)
         , @c_ExternOrderkey  NVARCHAR(50)   --tlting_ext
         , @c_DropID          NVARCHAR(20)
         , @c_Storerkey       NVARCHAR(15)
         , @c_Sku             NVARCHAR(20)
         , @c_Short        NVARCHAR(1)
         , @c_Loc          NVARCHAR(10)
         , @c_DP           NVARCHAR(10)
         , @c_DPP          NVARCHAR(10)
         , @c_LocDP        NVARCHAR(10)
         , @c_LocDPP       NVARCHAR(10)

         , @d_Adddate      DATETIME


   SET @n_StartTCnt = @@TRANCOUNT

   CREATE TABLE #TMP_PICKPACK
            (  Wavekey           NVARCHAR(10)
            ,  ProcessingDate    DATETIME
            ,  ExternOrderkey    NVARCHAR(50)  --tlting_ext
            ,  Short             NVARCHAR(1)
            ,  Storerkey         NVARCHAR(15)
            ,  Sku               NVARCHAR(20)
            ,  DropID            NVARCHAR(20)
            ,  QtyPicked         INT
            ,  QtyPacked         INT
            ,  QtyRDTPackked     INT
            ,  LocDP             NVARCHAR(10)
            ,  LocDPP            NVARCHAR(10)
            )

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   DECLARE CUR_PICKPACK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT 
          WAVEDETAIL.WaveKey
         ,ORDERS.ExternOrderkey
         ,PICKDETAIL.DropID
         ,PICKDETAIL.Storerkey
         ,PICKDETAIL.Sku
   FROM WAVEDETAIL WITH (NOLOCK)
   JOIN ORDERS     WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)
   JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey)
   WHERE WAVEDETAIL.Wavekey    BETWEEN @c_WaveFrom        AND @c_WaveTo
   AND   ORDERS.ExternOrderkey BETWEEN @c_ExternOrderFrom AND @c_ExternOrderTo
   AND   PICKDETAIL.DropID     BETWEEN @c_DropIDFrom      AND @c_DropIDTo
   AND   PICKDETAIL.Sku        BETWEEN @c_SkuFrom         AND @c_SkuTo

   OPEN CUR_PICKPACK      
         
   FETCH NEXT FROM CUR_PICKPACK INTO @c_Wavekey
                                    ,@c_ExternOrderkey
                                    ,@c_DropID
                                    ,@c_Storerkey
                                    ,@c_Sku

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      SET @n_QtyPicked    = 0
      SET @n_QtyPacked    = 0
      SET @n_QtyRDTPacked = 0

      SET @c_Short  = 'N'
      SET @c_LocDP  = ''
      SET @c_LocDPP = ''

      IF @c_DropID <> '' 
      BEGIN
         SELECT @n_QtyPacked = ISNULL(SUM(Qty),0)
         FROM PACKDETAIL WITH (NOLOCK)
         WHERE DropID = @c_DropID
         AND   Storerkey = @c_Storerkey
         AND   Sku       = @c_Sku

         SELECT @n_QtyRDTPacked = ISNULL(SUM(CQty),0)
         FROM RDT.RDTPPA WITH (NOLOCK)
         WHERE DropID = @c_DropID
         AND   Storerkey = @c_Storerkey
         AND   Sku       = @c_Sku
      END

      SELECT TOP 1 @c_Short = 'Y'
      FROM ORDERS WITH (NOLOCK)
      JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
      JOIN PICKDETAIL  WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey)
                                     AND(ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderlineNumber)
      WHERE ORDERS.ExternOrderkey = @c_ExternOrderkey
      AND   PICKDETAIL.STATUS     <> '4'
      GROUP BY ORDERDETAIL.Orderkey
            ,  ORDERDETAIL.OrderLineNumber
            ,  ORDERDETAIL.OpenQty
      HAVING ORDERDETAIL.OpenQty > SUM(PICKDETAIL.Qty)


      DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ORDERS.AddDate
            ,PICKDETAIL.Loc
            ,SUM(PICKDETAIL.Qty)
      FROM ORDERS     WITH (NOLOCK)
      JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey)
      WHERE ORDERS.ExternOrderkey = @c_ExternORderkey
      AND   PICKDETAIL.DropID     = @c_DropID
      AND   PICKDETAIl.Storerkey  = @c_Storerkey
      AND   PICKDETAIL.Sku        = @c_Sku
      GROUP BY ORDERS.AddDate
            ,  PICKDETAIL.Loc
      
      OPEN CUR_PICKDETAIL     
 
      FETCH NEXT FROM CUR_PICKDETAIL INTO @d_Adddate
                                        , @c_Loc
                                        , @n_Qty 

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         SELECT @c_DP  = CASE WHEN LocationType = 'DYNPICKP' THEN @c_Loc ELSE '' END
               ,@c_DPP = CASE WHEN LocationType = 'DYNPPICK' THEN @c_Loc ELSE '' END
         FROM LOC WITH (NOLOCK)
         WHERE Loc = @c_Loc

         IF @c_DP <> '' 
         BEGIN
            SET @c_LocDP = @c_LocDP + @c_DP + ' / '
         END
   
         IF @c_DPP <> '' 
         BEGIN
            SET @c_LocDPP = @c_LocDPP + @c_DPP + ' / '
         END

         SET @n_QtyPicked = @n_QtyPicked + @n_Qty

         FETCH NEXT FROM CUR_PICKDETAIL INTO @d_Adddate
                                          ,  @c_Loc
                                          ,  @n_Qty 
      END
      CLOSE CUR_PICKDETAIL
      DEALLOCATE CUR_PICKDETAIL

      IF RIGHT(@c_LocDP,2) = '/ ' SET @c_LocDP  = SUBSTRING(@c_LocDP,1,LEN(@c_LocDP)-2)
      IF RIGHT(@c_LocDPP,2)= '/ ' SET @c_LocDPP = SUBSTRING(@c_LocDPP,1,LEN(@c_LocDPP)-2)
         
      INSERT INTO #TMP_PICKPACK
            (  Wavekey
            ,  ProcessingDate
            ,  ExternOrderkey
            ,  Short
            ,  Storerkey
            ,  Sku
            ,  DropID
            ,  QtyPicked
            ,  QtyPacked
            ,  QtyRDTPackked
            ,  LocDP
            ,  LocDPP
            )
      VALUES(
               @c_Wavekey
            ,  @d_AddDate
            ,  @c_ExternOrderkey
            ,  @c_Short
            ,  @c_Storerkey
            ,  @c_Sku
            ,  @c_DropID
            ,  @n_QtyPicked
            ,  @n_QtyPacked
            ,  @n_QtyRDTPacked
            ,  @c_LocDP
            ,  @c_LocDPP
            )
      FETCH NEXT FROM CUR_PICKPACK INTO @c_Wavekey
                                       ,@c_ExternOrderkey
                                       ,@c_DropID
                                       ,@c_Storerkey
                                       ,@c_Sku
   END
   CLOSE CUR_PICKPACK
   DEALLOCATE CUR_PICKPACK

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   SELECT Wavekey
      ,  ProcessingDate
      ,  ExternOrderkey
      ,  Short
      ,  Storerkey
      ,  Sku
      ,  DropID
      ,  QtyPicked
      ,  QtyPacked
      ,  QtyRDTPackked
      ,  QtyPicked - QtyRDTPackked
      ,  LocDP
      ,  LocDPP
   FROM #TMP_PICKPACK
END

GO