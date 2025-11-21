SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: ispCalPackSummary                                   */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Calculate Pack Summary                                      */
/*                                                                      */
/* Called By: PowerBuilder Pack Summary                                 */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 15-Aug-2005  Shong     1.0   Initial Version                         */
/* 25-May-2011  Ung       1.1   SOS216105 Configurable SP to calc       */
/*                              carton, cube and weight                 */
/* 23-Apr-2012  NJOW01    1.2   241032-Calculation by coefficient       */
/************************************************************************/
CREATE PROC [dbo].[ispCalPackSummary] 
   @c_PickSlipNo  NVARCHAR(10), 
   @n_CtnCnt1 int = 0 OUTPUT,
   @n_CtnCnt2 int = 0 OUTPUT,
   @n_CtnCnt3 int = 0 OUTPUT,
   @n_CtnCnt4 int = 0 OUTPUT,
   @n_CtnCnt5 int = 0 OUTPUT,
   @c_CtnTyp1 NVARCHAR(10) = 0 OUTPUT,
   @c_CtnTyp2 NVARCHAR(10) = 0 OUTPUT,
   @c_CtnTyp3 NVARCHAR(10) = 0 OUTPUT,
   @c_CtnTyp4 NVARCHAR(10) = 0 OUTPUT,
   @c_CtnTyp5 NVARCHAR(10) = 0 OUTPUT,
   @n_TotalWeight float = 0 OUTPUT,
   @n_TotalCube   float = 0 OUTPUT,
   @c_CartonGroup NVARCHAR(10) = '' OUTPUT 
AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE   @c_CartonType       NVARCHAR(10),   
          @n_CartonCube       float,   
          @n_PackedCube       float,   
          @n_TotalCarton      int,   
          @c_DefaultCartonType NVARCHAR(10),   
          @n_PackDetCtn        int, 
          @c_StorerKey        NVARCHAR(15),
          @c_OrderKey         NVARCHAR(10), 
          @c_LoadKey          NVARCHAR(10),
          @n_CtnCnt           int, 
          @n_CartonCnt        int, 
          @n_CartonWeight     float,  
          @cSP_Carton         SYSNAME,        -- SOS216105
          @cSP_Cube           SYSNAME,        -- SOS216105
          @cSP_Weight         SYSNAME,        -- SOS216105
          @cSQL               NVARCHAR( 400), -- SOS216105
          @cParam             NVARCHAR( 400), -- SOS216105
          @cSValue            NVARCHAR( 10),       -- SOS216105
          @n_Coefficient_carton float,  --NJOW01
          @n_Coefficient_cube   float,  --NJOW01
          @n_Coefficient_weight float   --NJOW01

SELECT @c_StorerKey = StorerKey, 
       @c_OrderKey  = OrderKey, 
       @c_LoadKey   = LoadKey
FROM   PACKHEADER WITH (NOLOCK)
WHERE  PickSlipNo = @c_PickSlipNo 

IF ISNULL(RTRIM(@c_OrderKey),'') = ''
BEGIN
   SELECT TOP 1 @c_OrderKey = OrderKey 
   FROM   LOADPLANDETAIL WITH (NOLOCK)
   WHERE  LoadKey = @c_LoadKey 
END 

IF RTRIM(@c_StorerKey) = '' OR @c_StorerKey IS NULL
BEGIN
   SELECT TOP 1 @c_StorerKey = ORDERS.StorerKey
   FROM ORDERS WITH (NOLOCK)
   WHERE OrderKey = @c_OrderKey
END

SELECT @c_CartonGroup = CartonGroup
FROM   STORER WITH (NOLOCK)
WHERE  StorerKey = @c_StorerKey

SELECT TOP 1 
       @c_DefaultCartonType = CartonType,
       @n_CartonCube        = [Cube]
FROM  CARTONIZATION WITH (NOLOCK)
WHERE CartonizationGroup = @c_CartonGroup
ORDER BY UseSequence ASC

SELECT @n_PackDetCtn = COUNT(DISTINCT CartonNo),
       @n_PackedCube = @n_CartonCube * COUNT(DISTINCT CartonNo)
FROM   PACKDETAIL WITH (NOLOCK)
WHERE PickSlipNo = @c_PickSlipNo

SELECT @c_CtnTyp1 = '', @c_CtnTyp2 = '', @c_CtnTyp3 = '', @c_CtnTyp4 = '', @c_CtnTyp5 = ''
SELECT @n_CtnCnt1 = 0, @n_CtnCnt2 = 0, @n_CtnCnt3 = 0, @n_CtnCnt4 = 0, @n_CtnCnt5 = 0
SET @n_TotalWeight = 0
SET @n_TotalCube = 0
SET @n_TotalCarton = 0

-- Check whether the PackInfo exists? if Yes, then PackInfo will overwrite pack summary
IF EXISTS(SELECT 1 FROM PACKINFO WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
BEGIN
   SET @n_CtnCnt = 1
   DECLARE CUR_PACKINFO_CARTON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT CartonType,
      COUNT(DISTINCT CartonNo),
      SUM(ISNULL(PACKINFO.Weight,0)),
      SUM(ISNULL(PACKINFO.Cube,0))
      FROM   PACKINFO WITH (NOLOCK)
      WHERE  PickSlipNo = @c_PickSlipNo 
      AND    (CartonType <> '' AND CartonType IS NOT NULL)
   GROUP BY CartonType

   OPEN CUR_PACKINFO_CARTON

   FETCH NEXT FROM CUR_PACKINFO_CARTON INTO @c_CartonType, @n_CartonCnt, @n_CartonWeight, @n_CartonCube
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @n_CtnCnt = 1
      BEGIN
         SET @c_CtnTyp1 = @c_CartonType
         SET @n_CtnCnt1 = @n_TotalCarton
      END
      IF @n_CtnCnt = 2
      BEGIN
         SET @c_CtnTyp2 = @c_CartonType
         SET @n_CtnCnt2 = @n_TotalCarton
      END
      IF @n_CtnCnt = 3
      BEGIN
         SET @c_CtnTyp3 = @c_CartonType
         SET @n_CtnCnt3 = @n_TotalCarton
      END
      IF @n_CtnCnt = 4
      BEGIN
         SET @c_CtnTyp4 = @c_CartonType
         SET @n_CtnCnt4 = @n_TotalCarton
      END
      IF @n_CtnCnt = 5
      BEGIN
         SET @c_CtnTyp5 = @c_CartonType
         SET @n_CtnCnt5 = @n_TotalCarton
      END
      SET @n_TotalWeight = @n_TotalWeight + @n_CartonWeight
      SET @n_TotalCube   = @n_TotalCube   + @n_CartonCube
      SET @n_TotalCarton = @n_TotalCarton + @n_CartonCnt

      SET @n_CtnCnt = @n_CtnCnt + 1
      FETCH NEXT FROM CUR_PACKINFO_CARTON INTO @c_CartonType, @n_CartonCnt, @n_CartonWeight, @n_CartonCube
   END
   CLOSE CUR_PACKINFO_CARTON
   DEALLOCATE CUR_PACKINFO_CARTON

END -- Packinfo exists
ELSE
BEGIN
   -- SOS216105 start. Configurable SP to calc carton, cube and weight
   SELECT @cSValue = SValue FROM StorerConfig WITH (NOLOCK) WHERE StorerKey = @c_Storerkey AND ConfigKey = 'CMSPackingFormula'
   
   IF @cSValue <> '' AND @cSValue IS NOT NULL
   BEGIN
      -- Get customize stored procedure
      SELECT 
         @cSP_Carton = Long, 
         @cSP_Cube = Notes, 
         @cSP_Weight = Notes2,
         @n_Coefficient_carton = CASE WHEN ISNUMERIC(UDF01) = 1 THEN 
                                      CONVERT(float,UDF01) ELSE 1 END,  --NJOW01
         @n_Coefficient_cube = CASE WHEN ISNUMERIC(UDF02) = 1 THEN
                                      CONVERT(float,UDF02) ELSE 1 END,  --NJOW01
         @n_Coefficient_weight = CASE WHEN ISNUMERIC(UDF03) = 1 THEN
                                      CONVERT(float,UDF03) ELSE 1 END  --NJOW01
      FROM CodeLkup WITH (NOLOCK)
      WHERE ListName = 'CMSStrateg'
         AND Code = @cSValue

      -- Run carton SP
      IF OBJECT_ID( @cSP_Carton, 'P') IS NOT NULL
      BEGIN
         SET @cSQL = 'EXEC ' + @cSP_Carton + ' @cPickSlipNo, @cOrderKey, ' + 
            '@cCtnTyp1 OUTPUT, @cCtnTyp2 OUTPUT, @cCtnTyp3 OUTPUT, @cCtnTyp4 OUTPUT, @cCtnTyp5 OUTPUT, ' + 
            '@nCtnCnt1 OUTPUT, @nCtnCnt2 OUTPUT, @nCtnCnt3 OUTPUT, @nCtnCnt4 OUTPUT, @nCtnCnt5 OUTPUT'
         SET @cParam = '@cPickSlipNo NVARCHAR( 10), @cOrderKey NVARCHAR( 10), ' + 
            '@cCtnTyp1 NVARCHAR( 10) OUTPUT, @cCtnTyp2 NVARCHAR( 10) OUTPUT, @cCtnTyp3 NVARCHAR( 10) OUTPUT, @cCtnTyp4 NVARCHAR( 10) OUTPUT, @cCtnTyp5 NVARCHAR( 10) OUTPUT, ' + 
            '@nCtnCnt1 INT OUTPUT, @nCtnCnt2 INT OUTPUT, @nCtnCnt3 INT OUTPUT, @nCtnCnt4 INT OUTPUT, @nCtnCnt5 INT OUTPUT'
         EXEC sp_executesql @cSQL, @cParam, @c_PickSlipNo, @c_OrderKey, 
            @c_CtnTyp1 OUTPUT, @c_CtnTyp2 OUTPUT, @c_CtnTyp3 OUTPUT, @c_CtnTyp4 OUTPUT, @c_CtnTyp5 OUTPUT, 
            @n_CtnCnt1 OUTPUT, @n_CtnCnt2 OUTPUT, @n_CtnCnt3 OUTPUT, @n_CtnCnt4 OUTPUT, @n_CtnCnt5 OUTPUT
         
         --NJOW01
         SET @n_CtnCnt1 = CONVERT(int, ISNULL(@n_CtnCnt1,0) * @n_Coefficient_carton)     
         SET @n_CtnCnt2 = CONVERT(int, ISNULL(@n_CtnCnt2,0) * @n_Coefficient_carton)     
         SET @n_CtnCnt3 = CONVERT(int, ISNULL(@n_CtnCnt3,0) * @n_Coefficient_carton)     
         SET @n_CtnCnt4 = CONVERT(int, ISNULL(@n_CtnCnt4,0) * @n_Coefficient_carton)     
         SET @n_CtnCnt5 = CONVERT(int, ISNULL(@n_CtnCnt5,0) * @n_Coefficient_carton)                 
      END
      
      -- Run cube SP
      IF OBJECT_ID( @cSP_Cube, 'P') IS NOT NULL
      BEGIN

         SET @cSQL = 'EXEC ' + @cSP_Cube + ' @cPickSlipNo, @cOrderKey, @nTotalCube OUTPUT'
         SET @cParam = '@cPickSlipNo NVARCHAR( 10), @cOrderKey NVARCHAR( 10), @nTotalCube FLOAT OUTPUT'
         EXEC sp_executesql @cSQL, @cParam, @c_PickSlipNo, @c_OrderKey, @n_TotalCube OUTPUT
         
         --NJOW01
         SET @n_TotalCube = ISNULL(@n_TotalCube,0) * @n_Coefficient_cube             
      END

      -- Run weight SP
      IF OBJECT_ID( @cSP_Weight, 'P') IS NOT NULL 
      BEGIN
         SET @cSQL = 'EXEC ' + @cSP_Weight + ' @cPickSlipNo, @cOrderKey, @nTotalWeight OUTPUT'
         SET @cParam = '@cPickSlipNo NVARCHAR( 10), @cOrderKey NVARCHAR( 10), @nTotalWeight FLOAT OUTPUT'
         EXEC sp_executesql @cSQL, @cParam, @c_PickSlipNo, @c_OrderKey, @n_TotalWeight OUTPUT

         --NJOW01
         SET @n_TotalWeight = ISNULL(@n_TotalWeight,0) * @n_Coefficient_weight             
      END
   END
   -- SOS216105 end. Configurable SP to calc carton, cube and weight
END

GO