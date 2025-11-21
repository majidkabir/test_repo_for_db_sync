SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/    
/* Store procedure: isp_IDXShopAddress                                       */    
/* Copyright      : IDS                                                      */    
/*                                                                           */    
/* Purpose: Process shop (consignee) address                                 */    
/*                                                                           */    
/* Modifications log:                                                        */    
/*                                                                           */    
/* Date       Rev  Author   Purposes                                         */    
/* 2013-12-18 1.0  James    Created                                          */    
/*****************************************************************************/    
    
CREATE PROC [dbo].[isp_IDXShopAddress](    
   @cConsigneeKey    NVARCHAR( 15), 
   @cCompany_OUT     NVARCHAR( 45)  OUTPUT, 
   @cAddress1_OUT    NVARCHAR( 45)  OUTPUT, 
   @cAddress2_OUT    NVARCHAR( 45)  OUTPUT, 
   @cAddress3_OUT    NVARCHAR( 45)  OUTPUT, 
   @cAddress4_OUT    NVARCHAR( 45)  OUTPUT, 
   @cZip_OUT         NVARCHAR( 18)  OUTPUT, 
   @cCity_OUT        NVARCHAR( 45)  OUTPUT,
   @cContact1_OUT    NVARCHAR( 30)  OUTPUT, 
   @cContact2_OUT    NVARCHAR( 30)  OUTPUT 

) AS    

   DECLARE 
      @cCompany      NVARCHAR( 45), 
      @cAddress1     NVARCHAR( 45), 
      @cAddress2     NVARCHAR( 45), 
      @cAddress3     NVARCHAR( 45), 
      @cAddress4     NVARCHAR( 45), 
      @cZip          NVARCHAR( 18), 
      @cCity         NVARCHAR( 45),
      @cContact1     NVARCHAR( 30), 
      @cContact2     NVARCHAR( 30) 

   SELECT 
      @cCompany   = Company, 
      @cAddress1  = Address1, 
      @cAddress2  = Address2, 
      @cAddress3  = Address3, 
      @cAddress4  = Address4, 
      @cZip       = Zip, 
      @cCity      = City, 
      @cContact1  = Contact1, 
      @cContact2  = Contact2 
   FROM dbo.Storer WITH (NOLOCK) 
   WHERE StorerKey = @cConsigneeKey 
   AND   Type = '2'

   IF @@ROWCOUNT = 0
   GOTO Quit

   IF ISNULL(@cAddress1, '') = ''
   BEGIN
      IF ISNULL(@cAddress2, '') <> ''
      BEGIN
         SET @cAddress1 = @cAddress2
         SET @cAddress2 = ''
      END
      ELSE 
         IF ISNULL(@cAddress3, '') <> ''
         BEGIN
            SET @cAddress1 = @cAddress3
            SET @cAddress3 = ''
         END
         ELSE
            IF ISNULL(@cAddress4, '') <> ''
            BEGIN
               SET @cAddress1 = @cAddress4
               SET @cAddress4 = ''
            END
               IF ISNULL(@cZip, '') <> ''
               BEGIN
                  SET @cAddress1 = RTRIM(@cZip) + CASE WHEN ISNULL(@cCity, '') <> '' THEN ', ' + @cCity ELSE '' END
                  SET @cZip = ''
                  SET @cCity = ''
               END
               ELSE
                  IF ISNULL(@cCity, '') <> ''
                  BEGIN
                     SET @cAddress1 = @cCity
                     SET @cCity = ''
                  END
   END

   IF ISNULL(@cAddress2, '') = ''
   BEGIN
      IF ISNULL(@cAddress3, '') <> ''
      BEGIN
         SET @cAddress2 = @cAddress3
         SET @cAddress3 = ''
      END
      ELSE 
         IF ISNULL(@cAddress4, '') <> ''
         BEGIN
            SET @cAddress2 = @cAddress4
            SET @cAddress4 = ''
         END
         ELSE
            IF ISNULL(@cZip, '') <> ''
            BEGIN
               SET @cAddress2 = RTRIM(@cZip) + CASE WHEN ISNULL(@cCity, '') <> '' THEN ', ' + @cCity ELSE '' END
               SET @cZip = ''
               SET @cCity = ''
            END
            ELSE
               IF ISNULL(@cCity, '') <> ''
               BEGIN
                  SET @cAddress2 = @cCity
                  SET @cCity = ''
               END
   END
   
   IF ISNULL(@cAddress3, '') = ''
   BEGIN
      IF ISNULL(@cAddress4, '') <> ''
      BEGIN
         SET @cAddress3 = @cAddress4
         SET @cAddress4 = ''
      END
      ELSE 
         IF ISNULL(@cZip, '') <> ''
         BEGIN
            SET @cAddress3 = RTRIM(@cZip) + CASE WHEN ISNULL(@cCity, '') <> '' THEN ', ' + @cCity ELSE '' END
            SET @cZip = ''
            SET @cCity = ''
         END
         ELSE
            IF ISNULL(@cCity, '') <> ''
            BEGIN
               SET @cAddress3 = @cCity
               SET @cCity = ''
            END
   END
   
   IF ISNULL(@cAddress4, '') = ''
   BEGIN
         IF ISNULL(@cZip, '') <> ''
         BEGIN
            SET @cAddress4 = RTRIM(@cZip) + CASE WHEN ISNULL(@cCity, '') <> '' THEN ', ' + @cCity ELSE '' END
            SET @cZip = ''
            SET @cCity = ''
         END
         ELSE
            IF ISNULL(@cCity, '') <> ''
            BEGIN
               SET @cAddress4 = @cCity
               SET @cCity = ''
            END
   END
   
   IF ISNULL(@cZip, '') = ''
   BEGIN
      IF ISNULL(@cCity, '') <> ''
      BEGIN
         SET @cZip = @cCity
         SET @cCity = ''
      END
   END

   SET @cCompany_OUT    = @cCompany   
   SET @cAddress1_OUT   = @cAddress1
   SET @cAddress2_OUT   = @cAddress2
   SET @cAddress3_OUT   = @cAddress3
   SET @cAddress4_OUT   = @cAddress4
   SET @cZip_OUT        = @cZip
   SET @cCity_OUT       = @cCity
   SET @cContact1_OUT   = @cContact1
   SET @cContact2_OUT   = @cContact2

   Quit:

GO